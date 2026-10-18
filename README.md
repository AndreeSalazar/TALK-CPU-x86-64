# TALK / Faggin scaling

Firmware propio desde cero, escrito byte por byte, para QEMU x86-64.
El desarrollo actual esta organizado en Faggin scaling/:

```text
Faggin scaling/
  16-bit/              reset, entrada real, A20, GDT y transicion a 32
  32-bit/              entrada protegida, paginacion y transicion a 64
  64-bit/              entrada larga, comprobacion con R8 y mensaje final
  build-firmware.ps1   selecciona las etapas y une sus bytes
```

Cada carpeta tiene su README, codigo y mensaje. Las etapas se ejecutan
en orden; las variantes permiten detenerse en 16, 32 o 64 bits.

## Ejecutar

Desde esta carpeta, con QEMU instalado:

```powershell
.\run-firmware.ps1
```

Salida del firmware:

```text
Faggin scaling: 16 bits OK
Faggin scaling: 32 bits OK
Faggin scaling: 64 bits OK
GREEN [CPU] guardians active
GREEN [Memory] integrity latch OK
GREEN [Memory] bounded allocator OK
```

Ctrl+C para salir. El perfil normal transmite por el puerto de depuracion de
QEMU. Para usar la consola propia con entrada por puerto serie:

```powershell
.\run-firmware.ps1 -Monitor
```

Teclas: `h` ayuda, `s` estado, `a` reservar 256 bytes, `o` hola mundo,
`e` eco, `q` detener; no hace falta Enter para elegir una orden.
En el eco puedes escribir, usar Enter y borrar; Escape regresa al monitor.
Los binarios propios se exportan como `build/hola.x86` y `build/eco.x86`.
Sus fuentes estan en [programs](Faggin%20scaling/64-bit/programs/README.md).
Los originales `src/hola.hex` y `src/eco.hex` se conservan como ejemplos UEFI.
Consulta [el contrato de la consola](Faggin%20scaling/64-bit/monitor/README.md)
y [las entregas pendientes](Faggin%20scaling/ENTREGAS.md).

Nuestra ROM sustituye el firmware
de la VM: no se carga SeaBIOS, OVMF ni un archivo .efi.

Elegir donde detenerse:

```powershell
.\run-firmware.ps1 -Stage 16
.\run-firmware.ps1 -Stage 32
.\run-firmware.ps1 -Stage 64
```

Pruebas que comprueban el orden de los mensajes y cierran su propia VM:

```powershell
.\run-firmware.ps1 -Stage 16 -Check
.\run-firmware.ps1 -Stage 32 -Check
.\run-firmware.ps1 -Stage 64 -Check
```

El lanzador busca QEMU en PATH y en C:\Program Files\qemu.
Tambien acepta -Qemu 'C:\otra ruta\qemu-system-x86_64.exe'.
Los binarios y registros quedan en build/, excluido de Git.

## Prueba sostenida de RAM

```powershell
.\run-firmware.ps1 -Stress
.\run-firmware.ps1 -Stress -Check
.\run-firmware.ps1 -Stress -InjectFault -Check
```

El firmware de 64 bits escribe y verifica 1 MiB durante 32 rondas. Cada
punto confirma una ronda; termina con RAM 1 MiB x 32 OK. La ultima variante
provoca una corrupcion en la RAM de la VM y exige RAM FAIL para comprobar
que el firmware la detecta. Las pruebas con -Check cierran su propia VM.

Los bytes y la explicacion estan en Faggin scaling/64-bit/stress/.
La investigacion sobre las fases de UEFI y el orden de desarrollo propio
esta en Faggin scaling/COMO-SE-CONSTRUYE-UN-FIRMWARE.md.

## Solidez antes de optimizar

La etapa de 64 bits instala IDT y TSS para informar excepciones con vector,
RIP, error, CR2 y pila utilizada. Las explicaciones estan en
Faggin scaling/64-bit/diagnostics/README.md.

```powershell
.\test-firmware.ps1
# Para observar un fallo de pagina provocado dentro de la VM:
.\run-firmware.ps1 -Exception page
```

La bateria completa exige catorce casos aprobados en QEMU y diecinueve reglas del
constructor, y escribe build/test-results.json y build/guardian-test-results.json.
Incluye nueve casos de CPU intencionales y una corrupcion de RAM: esos casos
deben ser detectados por el firmware, no son fallos de tu computadora.
Cada -Check exige tambien alcanzar el HLT final; el lanzador cierra su VM.

Cada ROM tiene un informe build/*-map.json con fuentes, SHA256 y conteo de
bytes explicitos frente al relleno. Es la referencia para reducir tamano
mas adelante, despues de comprobar el comportamiento.

## Guardianes globales

Cada archivo tiene un carril de ROM y cada recurso una reserva. Los cruces
y excesos bloquean la construccion con RED; un margen reducido o cobertura
pendiente avisa con YELLOW; las comprobaciones aprobadas muestran GREEN.
El estado agregado conserva el color mas grave.

En 64 bits, la CPU aplica paginas de guarda de pila, codigo de solo lectura
y datos no ejecutables. Puedes provocar un cruce real de pila dentro de la VM:

```powershell
.\run-firmware.ps1 -Exception stack -Check
```

Las reglas, sus motivos y limites estan en Faggin scaling/guardians/README.md.
Los informes de cada construccion usan el sufijo -guardians.json.
Los bloqueos incluyen codigo, propietario, motivo y correccion sugerida;
los contratos criticos tambien muestran bytes esperados y encontrados.
build/guardian-example.json contiene un ejemplo rojo de una copia de prueba.

## Servicio de memoria de 64 bits

Faggin scaling/64-bit/services/ implementa asignacion lineal de una arena de
512 KiB, alineacion a 16 bytes, limites, comprobacion de overflow y rechazo
sin consumir espacio ante rechazos normales. El ABI version 2 conserva una
bandera persistente si detecta corrupcion del cursor o su complemento.
Once autopruebas se ejecutan antes del destino final de cada perfil de 64 bits.
El mensaje GREEN [Memory] confirma que pasaron y el estado quedo limpio.

Se conservan los .hex manuales. La primera compactacion comprobada redujo
los bytes explicitos del perfil normal de 2319 a 2248, sin cambiar el ABI
ni quitar guardianes. Los detalles estan en Faggin scaling/COMPACTACION.md.
Esas cifras son historicas: la version 2 agrega nuevas protecciones y su
tamano actual se consulta en build/faggin-64-map.json.

## Experimentos anteriores

- src/hola.hex y src/eco.hex: aplicaciones UEFI; necesitan firmware UEFI.
- src/reset.hex: primera ROM de 16 bits, que solo emite un mensaje desde reset.
- build.ps1: conversor comun de hexadecimal comentado a bytes; no ensambla.

Los experimentos anteriores se conservan como referencia. Para construir
solamente la ROM original:

```powershell
.\build.ps1 -In src\reset.hex -Out build\talk-reset.rom
```

Este proyecto utiliza la RAM y los dispositivos emulados de QEMU. Todavia
no inicializa una placa fisica ni implementa la especificacion UEFI.
Los contratos, mapa de memoria y limites estan en Faggin scaling/README.md.
