#include <windows.h>
#include <winternl.h>
#include <ntstatus.h>
#include <stdio.h>

#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "kernel32.lib")

// NTSTATUS tanımları (eğer ntstatus.h düzgün yüklenmediyse)
#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS ((NTSTATUS)0x00000000L)
#endif

#ifndef STATUS_DLL_NOT_FOUND
#define STATUS_DLL_NOT_FOUND ((NTSTATUS)0xC0000135L)
#endif

// Gerisi...
// NTDLL fonksiyonları
typedef NTSTATUS(NTAPI* tLdrGetDllHandle)(
    _In_opt_ PWSTR DllPath,
    _In_opt_ PULONG DllCharacteristics,
    _In_ PUNICODE_STRING DllName,
    _Out_ PVOID* DllHandle
    );

typedef NTSTATUS(NTAPI* tLdrLoadDll)(
    _In_opt_ PWSTR SearchPath,
    _In_opt_ PULONG DllCharacteristics,
    _In_ PUNICODE_STRING DllName,
    _Out_ PVOID* DllHandle
    );

// Original fonksiyon işaretçileri
tLdrGetDllHandle OriginalLdrGetDllHandle = NULL;
tLdrLoadDll OriginalLdrLoadDll = NULL;

// Hook yapısı için
BYTE OriginalCode[20] = { 0 };
DWORD OldProtect = 0;

// Hooked LdrGetDllHandle
NTSTATUS NTAPI HookedLdrGetDllHandle(
    _In_opt_ PWSTR DllPath,
    _In_opt_ PULONG DllCharacteristics,
    _In_ PUNICODE_STRING DllName,
    _Out_ PVOID* DllHandle
)
{
    if (DllName && DllName->Buffer)
    {
        WCHAR* dllName = DllName->Buffer;

        // CRYPTBASE DLL'ini detect edip handle döndür
        if (wcsstr(dllName, L"CRYPTBASE") != NULL)
        {
            printf("[+] CRYPTBASE bypass: %ws\n", dllName);
            if (DllHandle)
                *DllHandle = (PVOID)0x140000000;
            return STATUS_SUCCESS;
        }

        // VirtualBox DLL'lerini gizle
        if (wcsstr(dllName, L"VBox") != NULL)
        {
            printf("[+] VirtualBox DLL gizlendi: %ws\n", dllName);
            return STATUS_DLL_NOT_FOUND;
        }

        // ISRT.DLL gizle (VM detection DLL)
        if (wcsstr(dllName, L"ISRT") != NULL)
        {
            printf("[+] ISRT.DLL gizlendi\n");
            return STATUS_DLL_NOT_FOUND;
        }
    }

    // Normal işle
    return OriginalLdrGetDllHandle(DllPath, DllCharacteristics, DllName, DllHandle);
}

// Simple inline hook - JMP patch
void PatchFunction(PVOID FunctionAddress, PVOID HookFunction, SIZE_T HookSize)
{
    DWORD OldProtect;

    // Memory'i yazılabilir yap
    VirtualProtect(FunctionAddress, HookSize, PAGE_EXECUTE_READWRITE, &OldProtect);

    // JMP komutu yaz (E9 = JMP rel32)
    BYTE jmp[] = { 0xE9 };  // JMP opcode
    memcpy(FunctionAddress, jmp, 1);

    // Offset hesapla
    DWORD offset = (DWORD)((DWORD64)HookFunction - (DWORD64)FunctionAddress - 5);
    memcpy((PBYTE)FunctionAddress + 1, &offset, 4);

    // Memory'i geri al
    VirtualProtect(FunctionAddress, HookSize, OldProtect, &OldProtect);
    FlushInstructionCache(GetCurrentProcess(), FunctionAddress, HookSize);
}

// DLL Entry Point
BOOL WINAPI DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved)
{
    if (dwReason == DLL_PROCESS_ATTACH)
    {
        // ntdll.dll'den LdrGetDllHandle'ı al
        HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
        if (!hNtdll)
            return FALSE;

        OriginalLdrGetDllHandle = (tLdrGetDllHandle)GetProcAddress(hNtdll, "LdrGetDllHandle");
        if (!OriginalLdrGetDllHandle)
            return FALSE;

        printf("[*] VM Detection Bypass DLL Loaded\n");
        printf("[*] LdrGetDllHandle hooked\n");

        // Hook'u uygula
        PatchFunction(OriginalLdrGetDllHandle, (PVOID)HookedLdrGetDllHandle, 20);

        DisableThreadLibraryCalls(hModule);
    }

    return TRUE;
}