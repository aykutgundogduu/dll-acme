# Önce exe'nin path'i doğru mu?
Test-Path "C:\DrakinGame\Binaries\GOD.exe"

# DLL path'i doğru mu?
Test-Path "D:\Repos\Inject\dllmain.dll"

# Exe başlatılabiliyor mu?
Start-Process "C:\DrakinGame\Binaries\GOD.exe" -WindowStyle Normal