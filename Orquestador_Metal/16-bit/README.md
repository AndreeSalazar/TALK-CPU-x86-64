# Etapa 1: 16 bits

Responsabilidad: arrancar desde reset, preparar una pila temporal y A20,
emitir su mensaje y, si se solicita, entrar en modo protegido.

Orden de ejecucion:

1. `reset.hex`: salto lejano en FFFFFFF0 que recarga CS para continuar en
   F000:0000, copia baja de nuestra ROM.
2. `entry.hex`: desactiva interrupciones enmascarables, establece SS:SP en
   0000:7000, DS=F000, habilita A20 por el puerto 92 y emite `message.hex`.
3. `halt.hex` detiene la variante de 16 bits; alternativamente `to-32.hex`
   carga `gdt.hex`, activa CR0.PE y salta al selector 08, direccion F0200.

`message.hex` y `gdt.hex` son datos; no se ejecutan como instrucciones.
Los prefijos 66 de `to-32.hex` permiten usar operandos de 32 bits desde
codigo de 16 bits. El salto lejano carga el descriptor de codigo de 32 bits.

Contrato de salida: GDT instalada, CR0.PE=1, CR0.PG=0,
CS=08 con base cero y D=1, IF=0, A20 activa. La siguiente etapa debe
recargar los segmentos de datos; no debe asumir que DS ya es plano.

Probar desde la raiz: `.\tools/qemu/run-firmware.ps1 -Stage 16 -Check`.
Esta variante excluye los archivos de las carpetas de 32 y 64 bits.
Las direcciones y selectores de este documento estan en hexadecimal.
