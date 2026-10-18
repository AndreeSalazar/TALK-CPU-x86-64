# Orquestador del Metal

## Ruta física actual

El usuario aceptó una entrada .efi mínima para cargar el programa propio desde FAT32
y abandonar los servicios de arranque antes de ejecutarlo. El [puente](../Puente_Metal/LEEME.md)
está implementado y probado en QEMU/OVMF (siete casos); la prueba física sigue
pendiente. No hay teclado/eco tras salir de UEFI en este prototipo. La investigación
desde RESET descrita más abajo se conserva como vía separada y su requisito de
no usar .efi ya no rige para esta primera prueba.


Esta es la carpeta técnica `Orquestador_Metal`. La secuencia de arranque
de 16, 32 y 64 bits conserva el nombre «Faggin scaling».
El objetivo físico único es MSI A320M-A PRO MAX (MS-7C52) con Ryzen 5 5600X.
QEMU es el banco de pruebas; no se busca implementar un UEFI universal.
La adaptación conservará los componentes AMD que necesite, si su integración
se demuestra viable. [Alcance y cierre físico](../PERFIL-FISICO.md).
Consulta [LEEME](LEEME.md) para orientarte y [Arranque propio](arranque/LEEME.md)
para distinguir el firmware desde RESET de un archivo de arranque en disco.

La implementación QEMU es propia desde cero, en homenaje a Federico Faggin. Sus instrucciones
estan escritas byte por byte en archivos .hex, sin ensamblador ni linker.
QEMU ejecuta nuestra ROM desde el reset, sin cargar SeaBIOS, OVMF ni .efi.

## Etapas separadas

| Carpeta | Responsabilidad |
| --- | --- |
| 16-bit/ | Reset, segmentos reales, pila temporal, A20, GDT y transicion a 32 |
| 32-bit/ | Segmentos planos, pila, tablas de paginas, PAE y transicion a 64 |
| 64-bit/ | Entrada larga, pila y comprobacion con R8 y un valor de 64 bits |

Cada etapa tiene su entrada, mensaje y README. Las transiciones estan en
16-bit/to-32.hex y 32-bit/to-64.hex. Las variantes de prueba usan halt.hex
en lugar de pasar al modo siguiente.

La separacion es de codigo y responsabilidades. No son procesos aislados por
el hardware: comparten CPU y memoria. La etapa de 32 bits necesita la de
16 bits; la de 64 bits necesita ambas anteriores. Los contratos de entrada
y salida se explican en cada carpeta.

## Ejecutar desde la raiz del repositorio

```powershell
.\run-firmware.ps1 -Stage 16
.\run-firmware.ps1 -Stage 32
.\run-firmware.ps1 -Stage 64
```

Salir con Ctrl+C antes de ejecutar el siguiente comando. Sin -Stage,
se ejecuta hasta 64 bits. La variante completa emite:

```text
Faggin scaling: 16 bits OK
Faggin scaling: 32 bits OK
Faggin scaling: 64 bits OK
GREEN [CPU] guardians active
GREEN [Memory] integrity latch OK
GREEN [Memory] bounded allocator OK
```

El perfil normal termina en HLT. Con `./run-firmware.ps1 -Monitor` desde la raiz
se abre la consola propia de 64 bits: `h` ayuda, `s` estado, `a` reserva, `q` parada.
La entrada llega por COM1 de QEMU, sin servicios BIOS/UEFI. Los mensajes
llegan a la terminal por el dispositivo debugcon de QEMU, puerto E9.

Prueba mas exigente: `.\run-firmware.ps1 -Stress`. Ejecuta 32 rondas sobre
1 MiB de RAM en 64 bits. Los bytes y las pruebas de deteccion de fallos
estan en `64-bit/stress/README.md`. La opcion -Stress se puede combinar
con -Check; -Stress -InjectFault -Check exige detectar la corrupcion provocada.

La arquitectura de referencia y los siguientes pasos se explican en
`COMO-SE-CONSTRUYE-UN-FIRMWARE.md`.

La entrada de 64 bits instala diagnostico antes de emitir su mensaje:
IDT, TSS y pilas IST. Las pruebas de errores reales y la interpretacion
de sus campos estan en `64-bit/diagnostics/README.md`.

Bateria completa: `.\test-firmware.ps1`. Comprueba 15 casos base en QEMU
y 33 reglas de guardianes, además de paquetes, pantalla/teclado, FAT32/MBR,
GPT y arranque. El [cierre v1](CIERRE-v1.md) contiene el desglose. Escribe `build/test-results.json` y
`build/guardian-test-results.json`. Los limites y semaforos se explican en
`guardians/README.md`.

La carpeta `64-bit/services/` contiene el servicio de memoria propio:
asignacion limitada a 512 KiB, tabla versionada y once autopruebas que
comprueban punteros, carry, errores y estado antes de continuar.

## Construir y comprobar

Solo construir, sin ejecutar:

```powershell
& '.\Orquestador_Metal\build-firmware.ps1' -Stage 64
```

El constructor selecciona y concatena los archivos respetando sus offsets,
y llama a ../build.ps1 para convertir los bytes y comprobar las marcas
=offset. No genera instrucciones automaticamente. Cada ROM mide 65536 bytes.
Las salidas son build/faggin-16.rom, build/faggin-32.rom y build/faggin-64.rom.
El hexadecimal combinado queda junto a cada ROM.
Cada construccion tambien genera `build/faggin-N-map.json` (o el nombre
de su variante), con SHA256, fuentes, bytes escritos explicitamente y
relleno. Es la referencia de tamano antes de optimizar: los 65536 bytes
de ROM incluyen el relleno necesario para este formato de imagen de PC.

Pruebas reales en QEMU que cierran su propia VM:

```powershell
.\run-firmware.ps1 -Stage 16 -Check
.\run-firmware.ps1 -Stage 32 -Check
.\run-firmware.ps1 -Stage 64 -Check
```

Cada prueba exige los mensajes exactos y en orden, sin etapas posteriores
a la elegida. En 64 bits se comprueba R8=1122334455667788 y se desplaza su
valor 32 posiciones antes de imprimir OK. Si falla, emite ! y se detiene.

Los registros se guardan en build/faggin-N-debug.log (texto),
build/faggin-N-instructions.log (instrucciones y registros de CPU) y
build/faggin-N-error.log (errores de QEMU).

La traza completa permite observar CS32 y despues CS64, EFER=D00 (LME,
LMA y NXE activos), CR3=1000, CR4.PAE=1 y CR0.WP=1. Registra bloques traducidos, no una
linea nueva por cada vuelta de un bucle.

## Mapa y limites actuales

Las direcciones de esta tabla estan en hexadecimal.

| Recurso | Ubicacion |
| --- | --- |
| Pila temporal de 16 bits | SS:SP = 0000:7000; crece hacia abajo |
| PML4, PDPT, PD y PT | RAM 1000-4FFF; las prepara 32-bit/to-64.hex |
| Pila de 32/64 bits | ESP/RSP = 90000; crece hacia abajo |
| ROM baja | F0000-FFFFF |
| GDT | F0100 inicialmente; copiada a RAM 6000 en 64 bits |
| TSS e IDT | RAM 7000-7067 y 8000-8FFF |
| Estado del servicio de memoria | RAM 9000-901F: cursor, complemento y bloqueo |
| Arena de asignacion | 100000-17FFFF; parte de WorkRAM |
| Entrada 32 bits | F0200, selector 08 |
| Entrada 64 bits | F1000 instala diagnostico; luego F0400, selector 18 |
| Vector de reset | FFFFFFF0, offset FFF0 de la ROM |

Se describe el primer tramo de 2 MiB con paginas de 4 KiB por identidad:
direccion virtual = direccion fisica. Pagina cero y guardas quedan no
presentes, datos NX y ROM solo lectura/ejecucion. Incluye tablas, pilas y ROM.
Los offsets y selectores son el contrato comun: cambiarlos exige ajustar
los archivos que los referencian. Las marcas comprueban los tamanos.

Destino: maquina pc, CPU qemu64, TCG, 16 MiB y un procesador. QEMU ofrece
RAM utilizable; este codigo no inicializa DDR4 ni el chipset de una placa
fisica. Las interrupciones enmascarables siguen desactivadas. Hay diagnostico
terminal de excepciones en 64 bits; faltan diagnostico temprano, recuperacion
y la integración física del perfil elegido. NMI y machine check tienen pila reservada,
pero no se han probado mediante inyeccion de eventos de hardware.
No es una imagen para grabar en la MSI A320M-A PRO MAX.

## Adaptación física: estado separado

El [análisis oficial MSI](../EVIDENCIAS/PC_REAL/analisis-msi/LEEME.md) y el
[trazado AMD/PEI](../EVIDENCIAS/PC_REAL/analisis-msi/TRAZADO-Y-ENTREGA.md)
son utilidades offline del anfitrión, con 16 comprobaciones aprobadas. No son
instrucciones de firmware ni una imagen de placa. La ruta activa del 5600X,
la entrega a código propio y los dispositivos físicos siguen pendientes.
Conservar módulos AMD puede exigir conservar o proporcionar su entorno PI/UEFI
y partes de AMI; no se añade por ello una aplicación .efi al USB.

## Referencia tecnica

[AMD64 Architecture Programmer's Manual, volumen 2](https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/24593.pdf):
activacion de long mode mediante CR4.PAE, CR3, EFER.LME, CR0.PG y un
segmento de codigo con L=1 y D=0.
