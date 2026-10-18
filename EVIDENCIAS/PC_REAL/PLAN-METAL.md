# Llegar al metal: contrato de la siguiente entrega

Decisión confirmada: firmware propio desde RESET, sin cargador .efi.
El objetivo físico sigue pendiente; el resultado QEMU no se presenta como soporte MSI.

## FAT32 y GOP cumplen funciones diferentes

FAT32 organiza archivos. Necesita debajo un controlador que pueda leer el dispositivo.
El lector actual está probado sobre ATA PIO/IDE PIIX de QEMU. El inventario de la placa
real enumera SATA AHCI y NVMe; arrancar de USB requeriría además su controlador USB
y transporte de almacenamiento. Conservar FAT32 es posible, pero copiar la ROM o
METAL/INICIO.X86 al volumen no crea la primera instrucción de RESET de la placa.

GOP es Graphics Output Protocol: una interfaz de firmware para consultar/configurar
modos y operar una salida gráfica. Lo proporciona un controlador; no es un protocolo
de comandos nativo que la RTX ejecute por recibir un archivo. En la ruta UEFI, el
controlador deja configurado un framebuffer que se puede seguir usando después de
ExitBootServices cuando el modo ofrece acceso directo. Las funciones GOP ya no
están disponibles tras salir de los servicios de arranque.

Con RESET propio no se presupone ese controlador ni un framebuffer configurado.
Hace falta inicialización de vídeo apropiada. Se puede diseñar una interfaz propia
de framebuffer y conservar el dibujo de letras, pero eso no inicializa por sí solo
la RTX 3060. La v1 configura VGA emulada; no incorpora un controlador RTX.

## Orden de trabajo con criterios observables

| Paso | Qué falta | Evidencia para avanzar |
|---|---|---|
| 1. Identificación y recuperación | Marcado completo del chip, tensión, capacidad, encapsulado y acceso compatible | Fotos físicas, hoja de datos exacta, lecturas completas verificadas y procedimiento de restauración |
| 2. Inicio de placa | Mapa de firmware y requisitos de la plataforma Ryzen; código específico desde RESET | Imagen revisada para esa placa y señal de diagnóstico temprano reproducible |
| 3. Memoria y modos | Inicialización DDR4, mapa de RAM y reservas físicas; adaptar los contratos 16/32/64 | Pruebas de memoria y excepciones ejecutadas en el equipo |
| 4. Vídeo | Inicializar la salida de la RTX o una alternativa expresamente elegida | Patrón visible y datos del modo/framebuffer medidos en hardware |
| 5. Almacenamiento | Elegir un transporte primero y desarrollar su controlador | Lecturas conocidas verificadas antes de montar FAT32 |
| 6. Programa externo | Integrar lector FAT32 y cargador con el mapa físico nuevo | Saludo/eco, rechazos explicados y fotos reales dentro de EVIDENCIAS/PC_REAL |

Un SSD SATA, un SSD NVMe y un USB son transportes distintos. La primera prueba no
promete soportarlos todos a la vez. El destino físico concreto se elegirá después
de resolver identificación e inicio; no se formatea ningún disco para simular progreso.

## Guardián de plataforma

El constructor acepta `-Platform QEMU` (predeterminado). Si se solicita
`-Platform MS-7C52`, emite `RED [FG-PLATFORM]` con el motivo y se detiene antes de
crear o modificar la salida. El mapa generado identifica QEMU explícitamente.
No es un detector universal de hardware ni impide que alguien grabe manualmente
una ROM: delimita lo que este constructor sabe generar.

Este guardián no se retira solo para obtener un archivo. Debe reemplazarse por la
selección de fuentes y contratos propios de la placa cuando exista ese port.
La lógica FAT32 y las instrucciones actuales se conservan; no se genera un .efi.

## Punto de partida físico

La [guía de identificación y recuperación](IDENTIFICACION-Y-RECUPERACION.md)
contiene las fotos necesarias. El modelo del chip y su tensión no se deducen de
la versión 2.C0 de BIOS. Aún no hay programador identificado ni copia de recuperación.
No se puede tomar desde Windows una fotografía de la inscripción física del chip.

## Referencia GOP

[TianoCore: QueryMode, SetMode y Blt](https://tianocore-docs.github.io/edk2-UefiDriverWritersGuide/draft/23_graphics_driver_design_guidelines/232_graphics_output_protocol_implementation/2324_querymode%2C_setmode%2C_and_blt_implementation.html)
describe la configuración del framebuffer por el controlador y su uso directo
posterior a ExitBootServices. Es referencia de interfaz, no soporte RTX en este proyecto.
