# Cierre de la primera version en QEMU

El objetivo es un firmware propio que arranca desde RESET, ejecuta sus bytes en
16, 32 y 64 bits y permite cargar un binario propio. Implementar la especificacion
UEFI completa o arrancar en cualquier placa no forma parte de esta primera version.

1. **Consola: implementada.** Controlador serie propio, consulta de estado,
   reservas de memoria protegidas y parada. Iniciar con `./run-firmware.ps1 -Monitor`.
2. **Carga de binario: pendiente.** Definir formato propio, entrada y regiones
   permitidas; recibirlo, comprobar longitud e integridad, y transferir el control.
   Una entrada rechazada debera explicar el motivo y conservar el monitor operativo.
3. **Cierre y compactacion: pendiente.** Probar carga valida, truncada, corrupta
   y fuera de limites; documentar el contrato de entrega; reducir instrucciones
   conservando los `.hex` y repetir los mismos contratos funcionales.

La base existente ya incluye transiciones, permisos de paginas, diagnosticos de
excepciones, prueba de RAM y asignador con bloqueo persistente por corrupcion.
Los guardianes de construccion verifican limites y contratos concretos; no prueban
automaticamente el significado de cualquier instruccion agregada.

El trabajo en placa fisica es otra entrega: necesita inicializacion de esa
plataforma. Una ROM que funciona en QEMU no demuestra que funcione en Ryzen.
