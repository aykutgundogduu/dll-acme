# Admin PowerShell ile çalıştırın
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$exe = "C:\DrakinGame\Binaries\GOD.exe"
$dll = "D:\Repos\Inject\dllmain.dll"

$code = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class Injector {
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    private static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out uint lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    const uint MEM_COMMIT = 0x1000;
    const uint PAGE_READWRITE = 0x04;
    const uint PROCESS_ALL_ACCESS = 0x1F0FFF;

    public static bool Inject(string exePath, string dllPath) {
        try {
            Console.WriteLine("[*] Starting process: " + exePath);
            ProcessStartInfo psi = new ProcessStartInfo(exePath);
            psi.UseShellExecute = false;
            Process proc = Process.Start(psi);
            if (proc == null) { Console.WriteLine("[-] Could not start process"); return false; }
            Console.WriteLine("[+] PID: " + proc.Id);
            System.Threading.Thread.Sleep(2000);

            IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, proc.Id);
            if (hProcess == IntPtr.Zero) { Console.WriteLine("[-] OpenProcess failed: " + Marshal.GetLastWin32Error()); return false; }

            byte[] dllBytes = System.Text.Encoding.ASCII.GetBytes(dllPath + "\0");
            IntPtr remoteAddr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)dllBytes.Length, MEM_COMMIT, PAGE_READWRITE);
            if (remoteAddr == IntPtr.Zero) { Console.WriteLine("[-] VirtualAllocEx failed: " + Marshal.GetLastWin32Error()); return false; }

            uint written;
            if (!WriteProcessMemory(hProcess, remoteAddr, dllBytes, (uint)dllBytes.Length, out written)) {
                Console.WriteLine("[-] WriteProcessMemory failed: " + Marshal.GetLastWin32Error());
                return false;
            }

            IntPtr hKernel32 = GetModuleHandle("kernel32.dll");
            IntPtr pLoadLibraryA = GetProcAddress(hKernel32, "LoadLibraryA");
            if (pLoadLibraryA == IntPtr.Zero) { Console.WriteLine("[-] GetProcAddress failed"); return false; }

            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, pLoadLibraryA, remoteAddr, 0, out IntPtr threadId);
            if (hThread == IntPtr.Zero) { Console.WriteLine("[-] CreateRemoteThread failed: " + Marshal.GetLastWin32Error()); return false; }

            WaitForSingleObject(hThread, 10000);
            CloseHandle(hThread);
            CloseHandle(hProcess);

            Console.WriteLine("[+] Injection complete");
            return true;
        } catch (Exception ex) {
            Console.WriteLine("[-] Exception: " + ex.Message);
            return false;
        }
    }
}
"@

# Add-Type derleme ve hata yakalama
try {
    Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
} catch {
    Write-Host "Add-Type failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Tip mevcut mu kontrol (hata nedeni sık TypeNotFound olur)
$t = [System.Type]::GetType("Injector")
if ($t -eq $null) {
    # alternativ: Add-Type tarafından oluşturulan tipler içeriğini listele
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
        $_.GetTypes() | Where-Object { $_.Name -eq "Injector" } | ForEach-Object { Write-Host "Found in assembly:" $_.Assembly.FullName }
    }
    Write-Host "Type 'Injector' not found. Add-Type compilation likely failed." -ForegroundColor Red
    exit 1
}

# Injection çağrısı
$result = [Injector]::Inject($exe, $dll)
if ($result) { Write-Host "[+] Injection succeeded" -ForegroundColor Green } else { Write-Host "[-] Injection failed" -ForegroundColor Red }