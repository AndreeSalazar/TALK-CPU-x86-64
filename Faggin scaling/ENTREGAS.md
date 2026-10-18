# Cierre de la primera version en QEMU

El objetivo es un firmware propio que arranca desde RESET, ejecuta sus bytes en
16, 32 y 64 bits y permite cargar un binario propio. Implementar la especificacion
UEFI completa o arrancar en cualquier placa no forma parte de esta primera version.

1. **Consola: implementada.** Controlador serie propio, consulta de estado,
   reservas de memoria protegidas y parada. Iniciar con `./run-firmware.ps1 -Monitor`.
2. **Carga desde ROM: implementada.** Formato propio FAGRAW64, pagina dedicada,
   comprobacion de tamano, punto de entrada, flags y checksum antes de ejecutar.
   `o` ejecuta hola mundo; `e` permite escribir con eco y Escape retorna al monitor.
   Se prueban ocho rechazos y la continuidad del monitor tras cada uno.
3. **Entrada externa y compactacion: pendiente.** Recibir un paquete por un medio
   elegido, medir su longitud real y rechazar transferencias truncadas. Despues,
   reducir instrucciones conservando los `.hex` y repetir los contratos funcionales.

Los `.x86` actuales se exportan y se incluyen en la ROM al construirla. El
firmware todavia no busca archivos en USB/disco ni recibe paquetes por la consola.
La prueba de integridad es una suma de bytes; detecta las alteraciones probadas,
no autentica programas ni detecta modificaciones que conserven la suma.

La base existente ya incluye transiciones, permisos de paginas, diagnosticos de
excepciones, prueba de RAM y asignador con bloqueo persistente por corrupcion.
Los guardianes de construccion verifican limites y contratos concretos; no prueban
automaticamente el significado de cualquier instruccion agregada.

El trabajo en placa fisica es otra entrega: necesita inicializacion de esa
plataforma. Una ROM que funciona en QEMU no demuestra que funcione en Ryzen.
