# Consola propia de 64 bits

Desde la raiz: `./run-firmware.ps1 -Monitor`. No requiere Enter.

| Tecla | Resultado |
|---|---|
| `h` | Ayuda |
| `s` | Cursor actual y bandera persistente del asignador, en hexadecimal |
| `a` | Reservar 256 bytes; mostrar direccion o codigo de rechazo |
| `q` | Informar parada y ejecutar HLT |

Ctrl+C termina QEMU. `q` detiene la CPU virtual; QEMU sigue abierto.
CR/LF se ignoran. Una tecla desconocida produce YELLOW y explica como pedir ayuda.

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

`./run-firmware.ps1 -Monitor -Check` verifica ocho intercambios exactos: inicio,
ayuda, estado, dos reservas consecutivas, estado actualizado, orden desconocida y
parada. Tambien comprueba las autopruebas anteriores, HLT y ausencia de excepciones.
El registro queda en `build/faggin-64-monitor-console.log`.

Limites: una CPU, sin interrupciones de dispositivos, sin editor de linea ni
control de flujo. Enviar una orden cada vez evita desbordar el FIFO de entrada.
La prueba no simula una averia del transmisor; el timeout no implica cobertura
de todos los fallos posibles del UART.
