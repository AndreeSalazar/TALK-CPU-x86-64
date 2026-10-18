# Arranque propio desde RESET

## Decisión actual de la primera prueba física

El usuario aceptó una entrada .efi mínima para cargar el programa propio desde FAT32
y abandonar los servicios de arranque antes de ejecutarlo. El [puente](../../Puente_Metal/LEEME.md)
está implementado y probado en QEMU/OVMF (siete casos); la prueba física sigue
pendiente. No hay teclado/eco tras salir de UEFI en este prototipo. La investigación
desde RESET descrita más abajo se conserva como vía separada y su requisito de
no usar .efi ya no rige para esta primera prueba.


Vía de investigación desde RESET: conservar el firmware propio, sin una entrada `.efi`; la primera prueba física actual usa el puente autorizado arriba.
Destino físico único: MS-7C52 con Ryzen 5 5600X, según el
[perfil acordado](../../PERFIL-FISICO.md). Se investiga conservar componentes AMD
y el entorno de inicio que requieran; no implementar UEFI para cualquier placa.
Esta carpeta documenta el contrato de arranque. Ya existe lectura propia de
disco IDE y búsqueda en FAT32 dentro de QEMU, con el alcance descrito en
[storage](../64-bit/storage/README.md).

## Dos responsabilidades distintas

**Iniciar el firmware.** La CPU comienza con el código accesible desde su vector
de RESET. En QEMU, el lanzador instala nuestra imagen mediante `-bios`. En una
placa física se necesita una imagen adaptada a esa plataforma y su mecanismo
de almacenamiento de firmware. Una carpeta del disco no sustituye ese mecanismo.
La ROM de QEMU no está preparada para grabarse en la placa MSI.

**Buscar un programa.** Una vez que Orquestador del Metal controla la máquina,
puede inicializar almacenamiento, reconocer un formato propio, escoger un
programa, validarlo y ejecutarlo. `d` busca `METAL\INICIO.X86` en el volumen
FAT32 adjunto. `o` y `e` seleccionan paquetes incluidos en la ROM.

Cambiar la extensión de un archivo, el nombre de la carpeta o una etiqueta del
disco no hace que el firmware de fábrica comprenda el formato FAGRAW64.
Tampoco Windows instala ese firmware por encontrar una carpeta con este nombre.

## Inspiración en UEFI

Se adopta la separación de responsabilidades: descubrimiento de medios,
política de selección, validación de la imagen y entrega del control. El formato
de programa sigue siendo FAGRAW64 y sus instrucciones siguen en `.hex`.

Como referencia, UEFI define una ruta x64 de medios extraíbles:
`EFI\BOOT\BOOTX64.EFI`. Esa convención pertenece a su gestor de arranque; no
se implementa ni se sustituye por renombrar nuestro archivo `.x86`.
[Especificación UEFI, gestor de arranque](https://uefi.org/specs/UEFI/2.11/03_Boot_Manager.html#removable-media-boot-behavior).

## Entrega comprobada en QEMU

El transporte es ATA PIO con esperas acotadas. La selección es una ruta fija
8.3 de FAT32, sin catálogo adicional: `METAL\INICIO.X86`. Se comprueban longitud,
geometría, cadenas y dos copias de FAT antes del cargador FAGRAW64. Hay pruebas
de ausencia, fragmentación, daños y recuperación del monitor.

El selector reconoce MBR y GPT. GPT exige cabeceras, CRC y copias coherentes.
FAT32 admite clústeres de 1..64 sectores en potencias de dos. El arranque
automático ya carga la ruta fija y devuelve el monitor si falla o retorna.
`d` permite reintentar. La selección entre varios candidatos sigue siendo
ambigua y se rechaza: la v1 requiere una única partición candidata.

La entrega QEMU está cerrada con sus límites declarados y capturas en
[CIERRE-v1](../CIERRE-v1.md). Soportar otros controladores y una placa física
pertenece a otro objetivo, no a una instalación automática desde el disco.

La adaptación física está acotada al perfil acordado, no a ampliar el catálogo
de placas. El [trazado del firmware MSI](../../EVIDENCIAS/PC_REAL/analisis-msi/TRAZADO-Y-ENTREGA.md)
ya identifica tablas y dependencias PEI. Aún no hay una entrega implementada
desde esos componentes al código propio ni imagen modificada lista para grabar.

El transporte externo no cambia el privilegio de los programas actuales. La
suma de bytes comprueba integridad básica; no aporta autenticación. El salto
a hardware físico será otra entrega, con inicialización y recuperación propias
de esa placa. No se modifica el disco personal ni el firmware instalado aquí.
