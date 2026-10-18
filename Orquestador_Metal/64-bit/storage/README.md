# Lector FAT32 propio desde RESET

Desde la raíz:

```powershell
.\iniciar.ps1 -Disco
```

Pulsa `d`. El firmware identifica el disco IDE emulado, lee el volumen FAT32,
busca `METAL\INICIO.X86`, reúne el paquete completo, comprueba su longitud y
lo entrega al cargador FAGRAW64. El ejemplo externo imprime:

```text
GREEN [FAT32] METAL/INICIO.X86
Hola desde mi disco FAT32!
```

`o` y `e` siguen usando los ejemplos de la ROM. El firmware no emplea INT 13h,
UEFI ni funciones de archivos del anfitrión para leer el disco. Todas las
instrucciones de lectura y búsqueda están escritas en `.hex`.

## Alcance de esta versión

| Componente | Soporte comprobado |
|---|---|
| Máquina | QEMU pc, controlador IDE PIIX, primario maestro |
| Transporte | ATA PIO, LBA28, lectura de sectores de 512 bytes |
| Volumen | FAT32 en LBA0 o dentro de una partición primaria MBR |
| MBR | Cuatro entradas; seleccionar una única FAT32 de tipo 0B/0C |
| Clúster | Un sector de 512 bytes |
| FAT | Dos copias espejadas; flags y versión del BPB en cero |
| Directorios | Nombres cortos 8.3, ruta fija `METAL\INICIO.X86` |
| Fragmentación | Directorios y archivo pueden tener cadenas no contiguas |
| Recursos | Hasta 64 clústeres por búsqueda de directorio; archivo de 25..4096 bytes |

Es un lector acotado de FAT32 estándar, no otro formato llamado FAT32. No
admite todavía GPT, particiones lógicas/extendidas, FAT12/FAT16, clústeres mayores, nombres largos, escritura,
AHCI, NVMe o USB. Un volumen no compatible se rechaza con una explicación.
El firmware no se instala en una placa física mediante esta imagen de disco.

FAT32 se eligió por compatibilidad y por permitir un lector inicial pequeño.
No es el sistema de archivos más eficiente para todas las cargas. El rendimiento
de esta implementación no se ha comparado con otros lectores o sistemas.

## Archivos

`ata.hex` contiene IDENTIFY, lectura y espera de DRQ. `volumes.hex` selecciona
el volumen y convierte LBA relativos en absolutos sin cruzar sus límites.
`volume-messages.hex` explica rechazos de particiones. `fat32.hex` valida el BPB,
recorre directorios y FAT y carga el archivo. `messages.hex` conserva nombres
8.3 y motivos de rechazo. `inicio.hex` es el paquete externo de demostración;
se convierte a binario sin incluirlo en la ROM.

`crear-disco.ps1` crea **solo un archivo** `build/disco-fat32.img` de 64 MiB.
Con `-MBR` crea `build/disco-fat32-mbr.img`: volumen de 64 MiB desde LBA2048,
con 65 MiB de tamaño total. `iniciar.ps1 -Disco` utiliza ahora esa imagen MBR.
Usa 32 sectores reservados, dos FAT de 1024 sectores, datos desde LBA2080,
raíz en el clúster 2 y 128992 clústeres de datos. Incluye FSInfo y copias del
sector de arranque. La clasificación FAT32 se calcula por cantidad de clústeres;
el texto de etiqueta por sí solo no define el formato.

El script genera su demostración por defecto. Para construir otra imagen:

```powershell
.\crear-disco.ps1 -Programa build/hola.x86
```

`crear-disco.ps1 -MBR -Programa build/hola.x86` prepara la variante particionada.
`iniciar.ps1 -Disco` vuelve a generar la demostración MBR en cada ejecución. Para
abrir una imagen personalizada sin regenerarla, desde la raíz:

```powershell
.\Orquestador_Metal\build-firmware.ps1 -Monitor
.\monitor-session.ps1 -Qemu 'C:\Program Files\qemu\qemu-system-x86_64.exe' -DiskImage build/disco-fat32.img
```

El controlador del firmware solo emite órdenes de lectura/identificación.
Además, QEMU usa `snapshot=on`: cualquier escritura del dispositivo se dirigiría
a una capa temporal, no a la imagen base. IDE no admite la conexión de esta
imagen con `readonly=on` en esta configuración de QEMU. No se accede a discos
físicos del anfitrión; las pruebas verifican SHA-256 antes y después.

## Guardianes y motivos

IDENTIFY determina la capacidad antes de leer. Cada LBA debe ser menor que esa
capacidad y cada espera de estado está acotada a 1000000 consultas, no segundos.
Se distinguen ausencia, timeout, error del dispositivo y LBA/capacidad inválidos.

El BPB se comprueba antes de usar sus campos: firma, sector, clúster, FAT,
versión, longitudes y operaciones aritméticas sin desbordamientos. El tamaño
del volumen no puede superar el del dispositivo; la FAT debe tener capacidad
para todos sus clústeres. Cada enlace se limita al rango de datos y se compara
en ambas copias de la FAT.

El selector distingue un sector con estructura FAT32 de un MBR. El primer
caso pasa a la validación estricta del BPB; el segundo recorre cuatro entradas.
Exige firma 55AA, indicadores de arranque 00/80 y que toda partición no vacía
tenga inicio y longitud positivos. Comprueba sumas sin desbordamiento, capacidad
del dispositivo y ausencia de cruces. Rechaza una selección FAT32 múltiple;
no tiene todavía menú para elegir entre ellas. Una entrada protectora EE produce
un rechazo explícito de GPT, sin interpretarla como FAT32.

El estado del volumen usa 9060..906F: inicio absoluto y longitud. El BPB no
puede anunciar más sectores que la partición. Cada lectura debe ser menor que
su longitud; solo entonces se suma el inicio y se verifica también la capacidad
ATA. El campo de sectores ocultos del BPB no se utiliza como dirección confiable.

Una búsqueda no puede recorrer más de 64 clústeres. Ese presupuesto evita un
bucle infinito, pero no identifica la causa exacta de toda cadena larga: el
mensaje indica `chain loop/length limit`. Una cadena de archivo debe terminar
exactamente donde lo exige su longitud. Se rechazan cadenas truncadas o sobrantes.

El sector temporal está en A000..A1FF; el paquete completo en B000..BFFF y el
estado en 9040..905F. Sus reservas no cruzan el asignador ni la página ejecutable.
El cargador exige que longitud de cabecera +24 coincida con el archivo y luego
valida firma, entrada, flags y suma. La página de ejecución conserva la política
RW/NX durante copia y RX durante ejecución. Los programas siguen privilegiados;
la suma de bytes no autentica contenido ni detecta todas las alteraciones.

## Pruebas

`./test-storage.ps1` ejecuta 26 casos con el lector real dentro de QEMU.
Los 14 originales cubren:
carga normal; directorios y archivo fragmentados; ausencia de disco; BPB
inválido; clúster no compatible; archivo ausente; clúster reservado; ciclo de
directorio; FAT divergentes; cadena truncada; cadena sobrante; tamaño excesivo;
longitud del paquete distinta del archivo; y contenido alterado.

Los otros 12 cubren MBR válido, FAT32 en la cuarta entrada, archivo y directorios
fragmentados dentro de la partición, tabla sin FAT32, inicio cero, indicador
inválido, suma de límites desbordada, cruce, selección ambigua, GPT protector,
partición más pequeña que su BPB y firma MBR dañada.

Cada rechazo comprueba que el monitor aún consulta estado y se detiene. Las
cargas válidas deben ejecutar desde RAM; las rechazadas no deben hacerlo. Los
casos de timeout y error físico ATA tienen salida definida, pero todavía no
se ha simulado una avería del dispositivo para ejercitarlos.
Las copias dañadas se eliminan cuando pasan su prueba; si una prueba falla,
su imagen queda disponible para revisión. Se conservan cuatro imágenes base:
directa y MBR, cada una en versión normal y fragmentada.

La batería general incluye estas pruebas. `./iniciar.ps1 -Disco -Comprobar`
verifica el recorrido del ejemplo externo sin abrir una ventana.

## Referencias

[Especificación UEFI, formato de sistema de archivos](https://uefi.org/specs/UEFI/2.11/13_Protocols_Media_Access.html#file-system-format)
y [documentación de dispositivos de QEMU](https://www.qemu.org/docs/master/system/qemu-manpage.html).
Para MBR se consultó [el formato de particiones de la especificación UEFI](https://uefi.org/specs/UEFI/2.11/05_GUID_Partition_Table_Format.html#legacy-master-boot-record-mbr).
Son referencias de formato y configuración: el firmware no incorpora servicios UEFI.
