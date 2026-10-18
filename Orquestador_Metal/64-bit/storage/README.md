# Almacenamiento propio desde RESET

`./iniciar.ps1 -Disco` prepara GPT/FAT32, arranca la ROM propia y ejecuta
`METAL/INICIO.X86`. El programa imprime `Hola desde mi disco FAT32!` y retorna
al monitor. `-Manual` permite cargarlo solo al pulsar `d`. Un rechazo explica
el motivo y conserva el monitor.

Las instrucciones del firmware proceden de los `.hex`. La lectura ATA no usa
servicios BIOS ni UEFI. Los scripts del anfitrión solo construyen archivos.

## Contrato de la versión 1

| Componente | Alcance comprobado |
|---|---|
| Máquina | QEMU pc, IDE PIIX, primario maestro |
| Transporte | ATA PIO, LBA28, sectores de 512 bytes |
| Volumen | FAT32 directo, partición primaria MBR o GPT |
| MBR | Una candidata 0B/0C; límites y cruces de las cuatro entradas |
| GPT | Dos cabeceras de 92 bytes; tablas de 128 entradas de 128 bytes |
| Selección GPT | Una candidata Basic Data o ESP con atributos cero |
| Clúster FAT32 | 1, 2, 4, 8, 16, 32 o 64 sectores |
| FAT | Dos copias espejadas; versión y flags BPB cero |
| Ruta | Nombres cortos 8.3: METAL/INICIO.X86 |
| Fragmentación | Directorios y archivo pueden usar cadenas no contiguas |
| Presupuesto | 64 clústeres por búsqueda; paquete de 25..4096 bytes |

GPT exige MBR protector, cabeceras y tablas consistentes, CRC32, GUID válidos,
particiones sin cruces ni UUID duplicados. La tabla principal empieza en LBA2;
el respaldo, 33 sectores antes del final. Se validan los rangos utilizables y
los campos de 64 bits deben caber en el alcance ATA. Una copia dañada se rechaza;
no hay reparación automática.

No incluye escritura, menú de particiones, MBR extendido, FAT12/16, nombres
largos, AHCI, NVMe ni USB. FAT32 se eligió por compatibilidad y sencillez; no
se afirma que sea el formato más rápido o pequeño para cualquier uso.

## Organización y guardianes

`ata.hex` identifica y lee con esperas acotadas. `volumes.hex` selecciona el
volumen y convierte LBA relativos comprobando límites. `gpt.hex` valida GPT e
implementa CRC32 IEEE; `gpt-messages.hex` explica rechazos.
`fat32-clusters.hex` monta FAT32, busca nombres y reúne el archivo por sectores.
`fat32.hex` conserva la entrada estable, comprobaciones de cadenas y errores.
`inicio.hex` es el programa externo y no se incorpora a la ROM.

En RAM: estado ATA/volumen/clúster 9040..907F; sector temporal A000..A1FF;
paquete B000..BFFF; buffers GPT C000..10FFF. Son direcciones de RAM distintas
de los offsets de las fuentes ROM. Los guardianes reservan esos rangos.

Cada lectura valida capacidad, partición, clúster y sector interno. Se comparan
los enlaces de ambas FAT. La cadena de archivo debe terminar exactamente donde
lo exige su longitud. El presupuesto de directorios evita esperas infinitas;
`chain loop/length limit` no identifica toda causa posible. Las esperas ATA
se acotan por consultas, no por segundos.

El cargador valida FAGRAW64: página RW/NX durante copia, RX durante ejecución
y RW/NX al retornar. CRC32 y la suma del paquete detectan errores concretos;
no autentican programas. El programa sigue privilegiado y debe retornar según
su contrato: los guardianes no impiden que cualquier programa válido se cuelgue.

## Imágenes y pruebas

`./crear-disco.ps1` crea FAT32 directo. `-MBR` o `-GPT` seleccionan particionado;
`-SectoresPorCluster 8` selecciona clústeres de 4096 bytes. `-Programa` acepta
un paquete propio y `-Fragmentado` prepara cadenas no contiguas. Solo crea
archivos en `build/`. `iniciar.ps1 -Disco` regenera la demostración GPT/SPC8.

`herramientas-imagen.ps1` calcula CRC y permite archivos dispersos en Windows.
Su utilidad C# se ejecuta en el anfitrión, no forma parte del firmware.
QEMU usa `snapshot=on`; las pruebas comparan las huellas de las imágenes antes
y después. Las copias alteradas se eliminan al pasar y se conservan si fallan.

`test-storage.ps1` comprueba 26 recorridos FAT32/MBR y rechazo.
`test-gpt.ps1` añade 24 casos: CRC, respaldo, rangos, cruces, selección ambigua,
UUID duplicado, ESP, última entrada y todos los tamaños de clúster admitidos,
incluyendo archivos de 4096 bytes y directorios fragmentados.
`test-arranque.ps1` comprueba arranque correcto, cabecera dañada y disco ausente;
captura pantalla y eco. La batería general incluye los tres scripts.
Las salidas de timeout y error físico ATA existen, pero no se ha simulado una
avería física del dispositivo. Véase el [cierre con fotos](../../CIERRE-v1.md).

## Referencias de formato

[GPT y MBR](https://uefi.org/specs/UEFI/2.11/05_GUID_Partition_Table_Format.html)
y [formato FAT](https://uefi.org/specs/UEFI/2.11/13_Protocols_Media_Access.html#file-system-format).
Usar esos formatos no requiere implementar los servicios UEFI.
