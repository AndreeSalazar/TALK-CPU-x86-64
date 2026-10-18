# Orquestador del Metal

Firmware propio x86-64 para aprender y controlar el arranque de **mi PC**, con
instrucciones escritas a mano en `.hex`. «Faggin scaling» conserva el nombre de
las etapas de 16, 32 y 64 bits, en homenaje a Federico Faggin.

**Un único objetivo físico: MSI A320M-A PRO MAX (MS-7C52) + Ryzen 5 5600X.**
Se investigará la integración conservando componentes AMD necesarios. No se
pretende construir un UEFI universal ni mantener soporte para otras placas.
El alcance y los criterios para terminar están en [PERFIL-FISICO](PERFIL-FISICO.md).

## Estado real

| Parte | Estado |
|---|---|
| Firmware desde RESET en QEMU | v1 terminada y probada: consola, pantalla, teclado, memoria, saludo/eco y carga FAT32 |
| Análisis del firmware oficial MSI 2.C | Inventario y trazado AMD/PEI implementados; 16 comprobaciones aprobadas |
| Firmware adaptado al PC físico | Pendiente: aún no hay imagen modificada para grabar |

La ROM de QEMU sustituye el firmware de la VM; no carga SeaBIOS, OVMF ni una
aplicación `.efi`. Para el equipo real se mantiene la decisión de no usar una
entrada `.efi` en USB. Conservar componentes AMD puede requerir conservar o
proporcionar fases internas PI/UEFI y partes de AMI: todavía no se ha completado
esa integración. «Propio» no convierte los componentes conservados en código nuestro.

## Ejecutar lo que ya funciona en QEMU

Desde la raíz, con QEMU instalado:

```powershell
.\iniciar.ps1
```

| Tecla | Acción |
|---|---|
| `h` | Ayuda |
| `s` | Estado de memoria |
| `a` | Reserva de 256 bytes |
| `o` | Hola mundo propio |
| `e` | Eco; Escape vuelve al monitor |
| `d` | Cargar METAL/INICIO.X86 del disco virtual adjunto |
| `q` | Detener la CPU virtual |

No hace falta Enter para elegir una orden. En el eco, Enter cambia de línea y
se puede borrar. `-SoloTerminal` usa UART sin ventana; `-Comprobar` ejecuta una
comprobación y cierra su VM. `q` detiene la CPU, no cierra QEMU.

Para ejecutar el programa externo automáticamente desde GPT/FAT32:

```powershell
.\iniciar.ps1 -Disco
```

El firmware busca `METAL/INICIO.X86`. Si falla o el programa retorna, queda el
monitor; `d` reintenta. `-Manual` desactiva el intento automático. El lanzador
regenera una imagen de disco en `build/`, sin escribir discos físicos. El lector
admite MBR, GPT y FAT32 directo, con clústeres de 512 bytes a 32 KiB dentro de
sus [límites documentados](Orquestador_Metal/64-bit/storage/README.md).

```powershell
.\preparar.ps1
.\build\Orquestador_Metal\INICIAR.ps1
```

El paquete contiene ROM, disco GPT/FAT32, ejemplos, lanzador y manifiesto SHA-256.
Es para QEMU; copiarlo a FAT32 no instala firmware desde RESET en la MSI.

## Organización del código propio

```text
Orquestador_Metal/
  16-bit/              RESET, entrada real y transición a 32 bits
  32-bit/              modo protegido, paginación y transición a 64 bits
  64-bit/              diagnóstico, memoria, monitor, programas y dispositivos QEMU
  guardians/           límites, reservas, contratos y motivos de rechazo
  arranque/            contrato de arranque
  build-firmware.ps1   selecciona fuentes .hex y comprueba la ROM
EVIDENCIAS/
  QEMU/                cuatro capturas y resultados de la batería
  PC_REAL/             inventario, fotos y análisis offline de MSI
```

Las etapas están separadas por responsabilidad; comparten CPU y memoria y se
necesitan en orden. No son procesos aislados por hardware.

```powershell
.\run-firmware.ps1 -Stage 16 -Check
.\run-firmware.ps1 -Stage 32 -Check
.\run-firmware.ps1 -Stage 64 -Check
```

Cada ROM QEMU mide 65536 bytes por su mapa fijo. Los perfiles históricos siguen
llamándose `faggin-*`. Sus mapas en `build/*-map.json` indican fuentes, bytes
explícitos, relleno, plataforma y SHA-256. El constructor copia nuestros bytes;
no ensambla ni genera instrucciones. [Guía técnica](Orquestador_Metal/README.md).

## Guardianes y comprobaciones

Rojo bloquea o rechaza con motivo; amarillo avisa de margen o cobertura; verde
confirma una comprobación concreta. En 64 bits hay páginas de guarda, permisos
RX/RW/NX, diagnóstico de excepciones y asignador acotado con bloqueo persistente
ante corrupción. No se utiliza Rust. [Contratos y límites](Orquestador_Metal/guardians/README.md).

```powershell
.\test-firmware.ps1
```

La batería QEMU incluye 15 casos base, 33 reglas del constructor, ocho rechazos
de paquetes, dos recorridos de pantalla/teclado, 26 casos FAT32/MBR, 24 GPT/clústeres
y tres de arranque. Los fallos provocados deben detectarse. Las pruebas cierran
sus propias VM y escriben informes bajo `build/`.

```powershell
.\run-firmware.ps1 -Stress -Check
.\run-firmware.ps1 -Stress -InjectFault -Check
.\run-firmware.ps1 -Exception stack -Check
```

La prueba de RAM hace 32 rondas sobre 1 MiB. Los otros comandos ejercitan detección
de corrupción y un fallo de guarda de pila dentro de la VM.

Para conservar las fotos y los informes de una batería completada:

```powershell
.\recopilar-evidencias.ps1
```

Véanse el [cierre QEMU](Orquestador_Metal/CIERRE-v1.md) y [EVIDENCIAS](EVIDENCIAS/LEEME.md).
Las reducciones históricas y su método están en [COMPACTACION](Orquestador_Metal/COMPACTACION.md);
la limpieza posterior quitó 739 bytes explícitos sin reducir el mapa de 64 KiB.

## Adaptación a este PC, conservando AMD

Se descargó y analizó la referencia oficial MSI 2.C, nominalmente la versión
reportada por Windows en el equipo. Se encontraron tablas AMD y módulos PEI,
incluidos componentes de Zen 3. El [inventario y el trazado](EVIDENCIAS/PC_REAL/analisis-msi/LEEME.md)
distinguen lo observado en el archivo de lo aún no confirmado en hardware.

```powershell
.\analizar-msi.ps1 -Descargar
```

Requiere Python 3; `-Python` permite indicar su ruta. Sin `-Descargar` reutiliza
el ZIP local. Ejecuta cinco comprobaciones del inventario y once del trazado.
No ejecuta componentes AMD, no parchea la ROM y no invoca un grabador. Estas
herramientas del anfitrión no sustituyen las instrucciones .hex del firmware.

El siguiente trabajo está limitado a resolver la ruta del 5600X, sus dependencias
y la entrega al código propio. Antes de escribir físicamente hacen falta el
original de esta unidad y una recuperación externa preparada. El constructor
rechaza `-Platform MS-7C52` con un motivo hasta que exista ese port; por defecto
solo genera `-Platform QEMU`.

## Referencias y trabajo histórico

- [Perfil físico único y criterio de cierre](PERFIL-FISICO.md).
- [Guía de archivos y uso](Orquestador_Metal/LEEME.md).
- [Estado de las entregas](Orquestador_Metal/ENTREGAS.md).
- [Investigación de las fases de firmware](Orquestador_Metal/COMO-SE-CONSTRUYE-UN-FIRMWARE.md).
- `src/hola.hex` y `src/eco.hex`: aplicaciones UEFI históricas; no son la ruta de entrada elegida.
- `src/reset.hex`: primera ROM de 16 bits; `build.ps1` convierte hexadecimal comentado a bytes.
