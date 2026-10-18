# Metadatos y archivos dispersos del anfitrion. No genera instrucciones del firmware.
if(-not ('MetalImageSupport' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class MetalImageSupport {
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool DeviceIoControl(SafeFileHandle h, uint code, IntPtr input, uint inputLength,
        IntPtr output, uint outputLength, out uint returned, IntPtr overlapped);
    public static void Sparse(FileStream file) {
        if (Environment.OSVersion.Platform != PlatformID.Win32NT) return;
        uint returned;
        if (!DeviceIoControl(file.SafeFileHandle, 0x900C4, IntPtr.Zero, 0, IntPtr.Zero, 0, out returned, IntPtr.Zero))
            throw new IOException("No se pudo marcar la imagen como archivo disperso.");
    }
    public static uint Crc(byte[] data, int length) {
        uint value=0xffffffff;
        for(int i=0;i<length;i++) {
            value ^= data[i];
            for(int bit=0;bit<8;bit++) value=(value>>1)^((value&1)!=0?0xedb88320u:0);
        }
        return ~value;
    }
}
'@
}
