# Entregas: QEMU terminado, un único perfil físico en desarrollo

## Nueva entrega: puente UEFI hacia código propio

El usuario aceptó una entrada .efi mínima para cargar el programa propio desde FAT32
y abandonar los servicios de arranque antes de ejecutarlo. El [puente](../Puente_Metal/LEEME.md)
está implementado y probado en QEMU/OVMF (siete casos); la prueba física sigue
pendiente. No hay teclado/eco tras salir de UEFI en este prototipo. La investigación
desde RESET descrita más abajo se conserva como vía separada y su requisito de
no usar .efi ya no rige para esta primera prueba.


Destino acordado: MSI A320M-A PRO MAX (MS-7C52) + Ryzen 5 5600X.
El [perfil físico](../PERFIL-FISICO.md) es la referencia de alcance y cierre.
No hay un objetivo de UEFI completo ni compatibilidad con otras placas.

## Versión 1 para QEMU: terminada

| Parte | Implementación y evidencia |
|---|---|
| CPU y memoria | RESET → 16 → 32 → 64 bits, permisos de página, excepciones y asignador con bloqueo persistente |
| Consola | UART, VGA y PS/2 propios; estado, reserva y parada |
| Programas | FAGRAW64, hola mundo y eco desde ROM a RAM; validación antes de ejecutar |
| Disco | ATA PIO, FAT32 directo/MBR/GPT y cadenas fragmentadas; paquete externo hasta 4096 bytes |
| Arranque | Búsqueda automática METAL/INICIO.X86; motivo de rechazo y monitor cuando falla o retorna |
| Tamaño | Retirados 739 bytes explícitos heredados sin uso; la ROM mantiene 64 KiB |
| Evidencias | Cuatro capturas reales de QEMU, registros y paquete con manifiesto |

La batería tiene 15 casos base, 33 reglas de construcción, ocho rechazos de paquetes,
dos recorridos de pantalla/teclado, 26 casos FAT32/MBR, 24 GPT/clústeres y tres de
arranque. [Cierre y límites](CIERRE-v1.md), [fotos e informes](../EVIDENCIAS/LEEME.md).
`./iniciar.ps1 -Disco` ejecuta la demostración; `./preparar.ps1` genera el paquete QEMU.

## Investigación de la referencia MSI: implementada

`./analizar-msi.ps1 -Descargar` obtiene la referencia oficial 2.C y ejecuta análisis
sin modificar ROM. El inventario identifica tablas AMD y volúmenes; el trazado
sigue enlaces con contexto de dominio y decodifica dependencias de 243 módulos PEI
visibles. Hay 5 + 11 comprobaciones aprobadas del análisis, separadas de las pruebas
QEMU y de cualquier prueba física.

La [evidencia técnica](../EVIDENCIAS/PC_REAL/analisis-msi/TRAZADO-Y-ENTREGA.md) identifica
interfaces PCD, variables y SMBus y mantiene sin confirmar la selección física del
5600X. Los nombres, checksums y dependencias no demuestran que los módulos puedan
llamarse de forma independiente ni que hayamos inicializado DDR4.

## Adaptación física de este PC: pendiente

Se eligió conservar componentes AMD necesarios. Puede hacer falta conservar o
proporcionar su entorno PI/UEFI y partes de AMI. Se mantiene el requisito de no
usar una aplicación .efi del USB como entrada del proyecto.

Falta implementar la entrega desde el inicio de plataforma a nuestro código,
adaptar los dispositivos de este perfil y preparar el original/recuperación antes
de una prueba física. No hay imagen modificada lista para grabar. El bloqueo
FG-PLATFORM para MS-7C52 permanece activo y explica ese motivo.

El cierre físico exige arranque repetible, pantalla, saludo/eco, carga FAT32
mediante un transporte comprobado y evidencias del equipo real. No exige convertir
el proyecto en firmware para todos los PC. Una demostración QEMU no cierra esa entrega.

## Límites que se mantienen

Los guardianes comprueban contratos concretos; no prueban el significado de cualquier
instrucción nueva. Los programas cargados son privilegiados. La suma del paquete y
los checksums de metadatos no autentican programas. El lector QEMU no proporciona
un controlador NVMe, AHCI o USB a la placa física.
