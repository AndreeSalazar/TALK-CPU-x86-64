# Prueba sostenida de memoria en 64 bits

El firmware ejecuta esta prueba despues de completar las etapas 16 -> 32 -> 64.
Las instrucciones siguen escritas byte por byte, sin servicios BIOS/UEFI.

Desde la raiz del proyecto:

```powershell
.\tools/qemu/run-firmware.ps1 -Stress
```

Cada punto confirma una ronda completa. Tras 32 puntos debe aparecer:

```text
GREEN [RAM] Faggin scaling: RAM 1 MiB x 32 OK
```

La CPU queda en HLT; salir con Ctrl+C. Para comprobar y cerrar automaticamente:

```powershell
.\tools/qemu/run-firmware.ps1 -Stress -Check
```

## Que comprueba

Region exclusiva 0x100000-0x1FFFFF: 1 MiB de RAM virtual, ya mapeada por
la etapa de 32 bits. No incluye las pilas, GDT, tablas de paginas ni ROM.
Cada ronda recorre 131072 valores de 8 bytes y realiza:

1. Escritura de un patron de 64 bits: direccion XOR semilla.
2. Lectura y comparacion hacia delante; escritura del complemento.
3. Lectura y comparacion del complemento hacia atras.
4. Inversion de la semilla y emision de un punto de progreso.

Son 32 rondas y 128 MiB de accesos explicitos a los datos de prueba:
64 MiB escritos y 64 MiB leidos. No es una medida del rendimiento de RAM
fisica ni una prueba exhaustiva de todos los tipos de fallo de memoria.
El destino es QEMU con CPU qemu64, una CPU virtual y 16 MiB de RAM.

## Verificar que detecta errores

```powershell
.\tools/qemu/run-firmware.ps1 -Stress -InjectFault -Check
```

En esta variante el firmware pone a cero el primer valor despues del llenado,
antes de verificarlo. Debe aparecer RAM FAIL, sin puntos de rondas completadas.
Con ambos indicadores, el lanzador exige ese fallo esperado para aprobar
la prueba negativa. Si el firmware ignora la corrupcion, la prueba no pasa.
Sin -InjectFault, cualquier RAM FAIL se considera un error.

La corrupcion es intencional y afecta solo la RAM de prueba de la VM.
No se escribe en discos. Las variantes generan ROM y registros separados.

## Archivos y contrato

- `../services/target-stress.hex`: elige F0600 despues de las autopruebas de memoria.
- `fill.hex`: selecciona 32 rondas y llena la region con datos.
- `clean.hex`: camino de verificacion normal.
- `corrupt.hex`: reemplazo exclusivo de clean.hex para la prueba negativa.
- `verify.hex`: comparaciones, inversion, progreso y salida HLT en 0xF06D8.
- `messages.hex`: textos OK y FAIL.

Entrada: modo de 64 bits, segmento CS=0x18, RAM de prueba mapeada RW,
DF=0 e interrupciones enmascarables desactivadas. Los registros generales
usados por la prueba se consideran destruidos al terminar.

ROM normal: build/faggin-64-stress.rom. ROM negativa:
build/faggin-64-stress-fault.rom. Cada una tiene 65536 bytes.
Los registros usan esos mismos nombres, con sufijos -debug.log,
-instructions.log y -error.log.

La traza de esta prueba registra bloques e interrupciones, sin volcar el
estado de CPU en cada vuelta: hacerlo produciria millones de registros.
Las variantes de transicion sin -Stress conservan sus trazas de registros.
