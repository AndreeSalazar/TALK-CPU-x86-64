# Etapa 3: 64 bits

Primera entrada: `diagnostics/init.hex` en RIP=F1000. Prepara IDT, TSS y
pilas IST, y continua en `entry.hex`, RIP=F0400. CS=18 con L=1 y D=0,
long mode activo,
mapa por identidad hasta 2 MiB, con pagina nula y guardas no presentes,
datos NX y ROM RX; interrupciones enmascarables desactivadas.

`entry.hex` prepara los segmentos de datos y RSP=90000. Luego escribe
1122334455667788 en R8, copia el valor a RAX y lo desplaza 32 posiciones:
el resultado debe ser 11223344. Esta comprobacion usa un registro extendido
y un operando de 64 bits; el mensaje OK se emite solo despues del calculo.

Si coincide, emite `message.hex` por el puerto E9 y pasa por
`services/transition.hex` a las autopruebas del servicio de memoria propio.
Despues termina en HLT o va a -Stress/-Exception segun el perfil.
Los contratos estan en `services/README.md`, `stress/README.md` y
`diagnostics/README.md`.
Si no coincide, emite `!` y se detiene; la comprobacion automatica falla.
Todavia no hay programa externo, teclado o consola interactiva.

MOV ESP,90000 establece RSP completo porque escribir un registro de 32 bits
en modo de 64 bits pone a cero su mitad alta. MOV ESI,F0500 prepara RSI
del mismo modo para recorrer el mensaje con LODSB.

Probar desde la raiz: `.\tools/qemu/run-firmware.ps1 -Stage 64 -Check`.
Necesita las etapas de 16 y 32 bits; esta carpeta solo contiene el codigo
que se ejecuta una vez alcanzado el modo de 64 bits.
Las direcciones y valores de registros indicados estan en hexadecimal.
