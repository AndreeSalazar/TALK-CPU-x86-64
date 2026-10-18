# Pantalla de Orquestador_Metal

Desde la raiz: `./run-firmware.ps1 -Monitor`. La ventana de QEMU muestra texto
80x25 y recibe teclado PS/2. `-Headless` deja solo la terminal; `-Check` no abre
ventana. `q` detiene la CPU virtual y conserva la pantalla; cerrar la ventana
termina QEMU. La terminal tambien admite Ctrl+C.

Los mismos paquetes hola y eco y su tabla de servicios siguen funcionando.
La salida del servicio putc ahora llega a UART y VGA; getc sondea UART y PS/2.
No se recompilaron ni cambiaron los bytes de los programas para dibujarlos.

## Archivos y contratos

| Archivo | Responsabilidad |
|---|---|
| video.hex | Inicializar VGA, cargar letras, duplicar salida y controlar cursor |
| keyboard.hex | Inicializar PS/2 con esperas acotadas y traducir teclas |
| registers.hex | Datos de registros del modo texto |
| messages.hex | Titulo y motivos de recuperacion |
| font.hex | 128 glifos de 8x16 |
| keymap.hex | Teclado US con Shift izquierdo y derecho |

El firmware programa los registros VGA y copia una fuente a la memoria de la
tarjeta. Escribe caracteres/atributos en B8000..B8F9F. No ejecuta INT 10h, BIOS,
UEFI, ni la option ROM de la tarjeta. El PCI VGA de QEMU ocupa el dispositivo 2.
El estado de consola usa 9020..902F, separado del asignador. IF permanece cero.

El cursor se valida antes de usarlo: una posicion >=2000 produce
`YELLOW [VGA] cursor invalid; reset` por el canal E9 y se recupera desde cero.
Al llenar la pantalla copia 24 filas hacia arriba y borra la ultima. CR, LF y
Backspace controlan el cursor; la secuencia de borrado visual la emite eco.

Cada escritura de inicializacion PS/2 espera como maximo 1 000 000 consultas.
Se comprueba el ACK del teclado; si falla se informa
`YELLOW [PS2] init timeout/ACK; use UART` y permanece disponible la terminal.
No es un limite en segundos. Esperar una tecla durante el uso normal es intencional.
Los dos Shift se siguen por separado. Releases, prefijos extendidos y teclas
sin traduccion no se devuelven como texto; no hay Caps Lock, cursores ni teclado
espanol todavia. Entradas AUX o con errores se descartan.

La cobertura actual es el VGA y PS/2 emulados de QEMU pc. Esto no inicializa
la GPU ni un teclado USB de una placa Ryzen.

## Pruebas

`./test-screen.ps1` envia teclas mediante el controlador de QEMU, verifica
mayusculas, escritura, borrado, Enter y Escape, lee los caracteres reales de
VGA y captura su imagen. Llena mas de 25 filas y comprueba desplazamiento y
cursor <2000. La captura revisable queda en `build/orquestador-metal.png`.
Comprueba tambien que no aparezcan excepciones de CPU ni un triple fallo.

`./test-screen.ps1 -InjectCursorFault` altera solo una copia de la ROM: coloca
el cursor fuera de rango y exige la explicacion YELLOW, la recuperacion y el
mismo recorrido funcional. La bateria general incluye ambos recorridos.
No se ha simulado todavia una averia del controlador PS/2.

## Referencias y letras

Se consultaron los valores de registros de modo texto en
[SeaBIOS stdvgamodes.c](https://github.com/coreboot/seabios/blob/master/vgasrc/stdvgamodes.c).
Solo se usan como referencia de configuracion; su firmware no se carga.
Los glifos son datos de dominio publico de Daniel Hepper, Marcel Sondaar e IBM,
de [font8x8](https://github.com/dhepper/font8x8). Se invirtio el orden de bits y
se duplicaron las filas de 8x8 a 8x16. El controlador y los servicios son los
bytes del proyecto; la fuente de letras tiene esta procedencia externa.
