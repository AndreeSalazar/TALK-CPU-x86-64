@{
    Hello=@{
        Package='build/Puente_Metal'
        SourceEFI='EFI/BOOT/BOOTX64.EFI'
        TargetEFI='EFI/ORQUESTADOR/METAL.EFI'
        Packet='METAL/INICIO.X86'
        Name='Orquestador del Metal (prueba)'
        Prefix='puente'
        Record='instalacion.json'
    }
    FlappyPreview=@{
        Package='build/Flappy_Metal/PC_PREVIEW'
        SourceEFI='EFI/ORQUESTADOR/FLAPPY.EFI'
        TargetEFI='EFI/ORQUESTADOR/FLAPPY.EFI'
        Packet='METAL/FLAPPY.X86'
        Name='Flappy Metal (prueba visual)'
        Prefix='flappy-preview'
        Record='flappy-preview-instalacion.json'
    }
}
