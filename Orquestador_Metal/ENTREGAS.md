# Cierre de la primera version en QEMU

El objetivo es un firmware propio que arranca desde RESET, ejecuta sus bytes en
16, 32 y 64 bits y permite cargar un binario propio. Implementar la especificacion
UEFI completa o arrancar en cualquier placa no forma parte de esta primera version.

1. **Consola: implementada.** Controlador serie propio, consulta de estado,
   reservas de memoria protegidas y parada. Pantalla VGA y teclado PS/2 propios,
   con titulo Orquestador_Metal. Iniciar con `./run-firmware.ps1 -Monitor`.
2. **Carga desde ROM: implementada.** Formato propio FAGRAW64, pagina dedicada,
   comprobacion de tamano, punto de entrada, flags y checksum antes de ejecutar.
   `o` ejecuta hola mundo; `e` permite escribir con eco y Escape retorna al monitor.
   Se prueban ocho rechazos y la continuidad del monitor tras cada uno.
3. **Entrada externa FAT32: implementada en QEMU.** `iniciar.ps1 -Disco` y `d`
   leen `METAL/INICIO.X86` por ATA PIO. Se validan BPB, cadenas, dos copias de
   FAT, longitud y paquete. Se descubre una partición primaria MBR o un volumen
   directo; hay 26 pruebas de carga y rechazo.
4. **GPT, geometría y arranque: implementados.** Se verifican dos cabeceras GPT,
   CRC32 y las tablas principal/respaldo; se admiten clústeres FAT32 de 1..64
   sectores en potencias de dos. El arranque automático vuelve al monitor si
   falla o retorna el programa. Hay 24 pruebas GPT/geometría y 3 de arranque.
5. **Cierre v1 QEMU: completado.** Cuatro capturas reales, informe de motivos,
   paquete con ROM/disco/lanzador y limpieza de 739 bytes heredados sin uso.
   Véase [CIERRE-v1](CIERRE-v1.md). La ROM sigue midiendo 64 KiB por su mapa.

Los ejemplos `o` y `e` se exportan y se incluyen en la ROM. `d` lee un paquete
externo desde el disco IDE virtual FAT32; aún no lee USB ni recibe por consola.
La prueba de integridad es una suma de bytes; detecta las alteraciones probadas,
no autentica programas ni detecta modificaciones que conserven la suma.

La base existente ya incluye transiciones, permisos de paginas, diagnosticos de
excepciones, prueba de RAM y asignador con bloqueo persistente por corrupcion.
Los guardianes de construccion verifican limites y contratos concretos; no prueban
automaticamente el significado de cualquier instruccion agregada.

El trabajo en placa fisica es otra entrega: necesita inicializacion de esa
plataforma. Una ROM que funciona en QEMU no demuestra que funcione en Ryzen.
