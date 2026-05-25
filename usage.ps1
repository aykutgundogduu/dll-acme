# Admin PowerShell'de:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

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
            Console.WriteLine("[*] Exe başlatılıyor: " + exePath);
            ProcessStartInfo psi = new ProcessStartInfo(exePath);
            psi.UseShellExecute = true;
            Process proc = Process.Start(psi);
            
            if (proc == null) {
                Console.WriteLine("[-] Exe başlatılamadı");
                return false;
            }
            
            Console.WriteLine("[+] Process başlatıldı (PID: {0})", proc.Id);
            System.Threading.Thread.Sleep(3000);
            
            IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, proc.Id);
            if (hProcess == IntPtr.Zero) {
                Console.WriteLine("[-] OpenProcess hatası: {0}", Marshal.GetLastWin32Error());
                return false;
            }
            Console.WriteLine("[+] Process handle açıldı");
            
            byte[] dllBytes = System.Text.Encoding.Ansi.GetBytes(dllPath);
            IntPtr remoteAddr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)(dllBytes.Length + 1), MEM_COMMIT, PAGE_READWRITE);
            
            if (remoteAddr == IntPtr.Zero) {
                Console.WriteLine("[-] VirtualAllocEx hatası: {0}", Marshal.GetLastWin32Error());
                CloseHandle(hProcess);
                return false;
            }
            Console.WriteLine("[+] Remote memory allocated");
            
            uint bytesWritten;
            if (!WriteProcessMemory(hProcess, remoteAddr, dllBytes, (uint)dllBytes.Length, out bytesWritten)) {
                Console.WriteLine("[-] WriteProcessMemory hatası: {0}", Marshal.GetLastWin32Error());
                CloseHandle(hProcess);
                return false;
            }
            Console.WriteLine("[+] DLL path yazıldı ({0} bytes)", bytesWritten);
            
            IntPtr hKernel32 = GetModuleHandle("kernel32.dll");
            IntPtr pLoadLibraryA = GetProcAddress(hKernel32, "LoadLibraryA");
            
            if (pLoadLibraryA == IntPtr.Zero) {
                Console.WriteLine("[-] LoadLibraryA bulunamadı");
                CloseHandle(hProcess);
                return false;
            }
            Console.WriteLine("[+] LoadLibraryA adresi: 0x{0:X}", pLoadLibraryA.ToInt64());
            
            IntPtr hThread;
            IntPtr hThreadId;
            hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, pLoadLibraryA, remoteAddr, 0, out hThreadId);
            
            if (hThread == IntPtr.Zero) {
                Console.WriteLine("[-] CreateRemoteThread hatası: {0}", Marshal.GetLastWin32Error());
                CloseHandle(hProcess);
                return false;
            }
            
            Console.WriteLine("[+] Remote thread oluşturuldu");
            WaitForSingleObject(hThread, 10000);
            Console.WriteLine("[+] DLL yüklendi!");
            
            CloseHandle(hThread);
            CloseHandle(hProcess);
            
            Console.WriteLine("[+] Injection başarılı!");
            return true;
        }
        catch (Exception ex) {
            Console.WriteLine("[-] HATA: " + ex.Message);
            Console.WriteLine(ex.StackTrace);
            return false;
        }
    }
}
"@

# Type'ı ekle
Add-Type -TypeDefinition $code -Language CSharp

# Parametreler
$exe = "C:\DrakinGame\Binaries\GOD.exe"
$dll = "D:\Repos\Inject\dllmain.dll"

Write-Host "[*] VM Detection Bypass Injector" -ForegroundColor Cyan
Write-Host "[*] Exe: $exe" -ForegroundColor Yellow
Write-Host "[*] DLL: $dll" -ForegroundColor Yellow
Write-Host ""

# Injection yap
$result = [Injector]::Inject($exe, $dll)

if ($result) {
    Write-Host "[+] Başarılı! Exe çalışıyor, bypass aktif" -ForegroundColor Green
} else {
    Write-Host "[-] Başarısız" -ForegroundColor Red
}


