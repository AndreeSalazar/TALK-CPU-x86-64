# Consola propia de 64 bits

Desde la raiz: `./tools/qemu/run-firmware.ps1 -Monitor`. Abre la ventana Orquestador del Metal.
Pulsa dentro de ella para escribir con su teclado PS/2; no requiere Enter para
elegir una orden. `-Headless` conserva solo la terminal. UART y VGA reciben la
misma salida; se acepta entrada por UART o PS/2, con prioridad a UART.

| Tecla | Resultado |
|---|---|
| `h` | Ayuda |
| `s` | Cursor actual y bandera persistente del asignador, en hexadecimal |
| `a` | Reservar 256 bytes; mostrar direccion o codigo de rechazo |
| `o` | Cargar el hola mundo propio desde ROM a RAM y ejecutarlo |
| `e` | Cargar el eco propio; Escape retorna al monitor |
| `d` | Buscar y ejecutar `METAL\INICIO.X86` en el disco FAT32 adjunto |
| `q` | Informar parada y ejecutar HLT |

Ctrl+C termina QEMU. `q` detiene la CPU virtual; QEMU sigue abierto.
`./iniciar.ps1 -Disco` desde la raíz prepara y adjunta el volumen de prueba.
Sin disco adjunto, `d` informa `RED [ATA] disk absent` y conserva el monitor.
En el monitor CR/LF se ignoran. En el eco producen una linea nueva;
BS/DEL borran visualmente. Una orden desconocida produce YELLOW y explica como pedir ayuda.

El controlador propio usa COM1 (0x3F8), 115200, 8N1, FIFO e interrupciones desactivadas.
Lee por sondeo; esperar una tecla es intencional. Cada transmision permite hasta
1 000 000 consultas del estado: si no responde, informa RED por el canal E9
independiente y detiene el firmware. Es un limite de iteraciones, no un reloj.
No se usan funciones BIOS ni UEFI. La configuracion corresponde a QEMU pc.

Los bytes siguen escritos en `console.hex`; el constructor solamente los copia.
El monitor entra despues de todas las autopruebas. Usa el asignador version 2:
CF indica rechazo y EDX explica el motivo. Nunca interpreta una reserva rechazada
como direccion. No libera ni borra bloques; una reserva no significa que contenga ceros.
La consola conserva las protecciones de memoria y las pilas de excepciones existentes.

`./tools/qemu/run-firmware.ps1 -Monitor -Check` verifica 19 intercambios exactos, incluyendo
hola mundo desde RAM, eco caracter a caracter, borrado, salto de linea y regreso.
Tambien comprueba las autopruebas anteriores, HLT y ausencia de excepciones.
El registro queda en `build/faggin-64-monitor-check-console.log`.
`./tools/tests/test-screen.ps1` verifica por separado la entrada PS/2, el texto en memoria
VGA, el desplazamiento de filas y una captura real de la pantalla.
La ejecucion interactiva usa registros separados con sufijo `-live`, para que
las pruebas no colisionen con una consola abierta.

Limites: una CPU, sin interrupciones de dispositivos, sin editor de linea ni
control de flujo. Enviar una orden cada vez evita desbordar el FIFO de entrada.
La prueba no simula una averia del transmisor; el timeout no implica cobertura
de todos los fallos posibles del UART.

## Arranque automático

`./iniciar.ps1 -Disco` ejecuta el programa externo antes de ofrecer el monitor.
`./iniciar.ps1 -Disco -Manual` conserva la carga únicamente con `d`.
`startup.hex` consulta la bandera de ROM: el constructor selecciona
`auto-enabled.hex` o `auto-disabled.hex`, nunca ambos. Un rechazo del disco
retorna al monitor con el motivo; un programa que retorna también.
