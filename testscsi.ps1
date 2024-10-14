# Define the necessary PInvoke signatures for CreateFile, DeviceIoControl, and CloseHandle.
$code = @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public class AtaSmart
{
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool DeviceIoControl(
        IntPtr hDevice,
        uint dwIoControlCode,
        IntPtr lpInBuffer,
        uint nInBufferSize,
        ref SCSI_ADDRESS lpOutBuffer,
        uint nOutBufferSize,
        ref uint lpBytesReturned,
        IntPtr lpOverlapped
    );

    public const uint GENERIC_READ = 0x80000000;
    public const uint GENERIC_WRITE = 0x40000000;
    public const uint FILE_SHARE_READ = 0x00000001;
    public const uint FILE_SHARE_WRITE = 0x00000002;
    public const uint OPEN_EXISTING = 0x00000003;
    public const uint IOCTL_SCSI_GET_ADDRESS = 0x41018;
    public const uint FILE_ATTRIBUTE_NORMAL = 0x80;

    [StructLayout(LayoutKind.Sequential)]
    public struct SCSI_ADDRESS
    {
        public uint Length;
        public byte PortNumber;
        public byte PathId;
        public byte TargetId;
        public byte Lun;
    }

    public static bool GetScsiAddress(string path, ref byte portNumber, ref byte pathId, ref byte targetId, ref byte lun)
    {
        IntPtr hDevice = CreateFile(path,
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            IntPtr.Zero);
        
        if (hDevice == IntPtr.Zero)
        {
            return false;
        }

        uint dwReturned = 0;
        SCSI_ADDRESS scsiAddr = new SCSI_ADDRESS();
        bool bRet = DeviceIoControl(hDevice, IOCTL_SCSI_GET_ADDRESS,
            IntPtr.Zero, 0, ref scsiAddr, (uint)Marshal.SizeOf(scsiAddr), ref dwReturned, IntPtr.Zero);

        CloseHandle(hDevice);

        portNumber = scsiAddr.PortNumber;
        pathId = scsiAddr.PathId;
        targetId = scsiAddr.TargetId;
        lun = scsiAddr.Lun;

        return bRet;
    }
}
"@

# Compile the code in PowerShell
Add-Type -TypeDefinition $code -Language CSharp

# Example usage in PowerShell
$portNumber = 0
$pathId = 0
$targetId = 0
$lun = 0

$path = "\\\\.\\PhysicalDrive0"  # Example physical drive

$result = [AtaSmart]::GetScsiAddress($path, [ref]$portNumber, [ref]$pathId, [ref]$targetId, [ref]$lun)

if ($result) {
    Write-Host "PortNumber: $portNumber"
    Write-Host "PathId: $pathId"
    Write-Host "TargetId: $targetId"
    Write-Host "Lun: $lun"
} else {
    Write-Host "Failed to get SCSI address."
}
