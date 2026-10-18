# Orquestador del Metal

Firmware propio para x86-64, escrito con instrucciones en `.hex` y probado
desde RESET en QEMU. El nombre para leer es **Orquestador del Metal**;
`Orquestador_Metal` es la forma de su carpeta, sin espacios ni ambigüedades.

## Empezar

Desde la raíz del repositorio:

```powershell
.\iniciar.ps1
```

| Acción | Tecla |
|---|---|
| Ver ayuda | `h` |
| Consultar el estado de memoria | `s` |
| Reservar 256 bytes | `a` |
| Ejecutar «Hola mundo» | `o` |
| Escribir con eco | `e` |
| Regresar del eco | Escape |
| Detener la CPU virtual | `q` |

No hace falta Enter para elegir una orden. Dentro del eco, Enter cambia de línea.
Cerrar la ventana termina QEMU; `q` conserva visible el último resultado.
`./iniciar.ps1 -SoloTerminal` usa solo la terminal. `-Comprobar` comprueba el
recorrido del monitor y cierra su propia máquina virtual; no abre ventana.

## Organización

`./preparar.ps1` desde la raíz deja un paquete en `build/Orquestador_Metal/`:
`firmware.rom`, los programas `.x86`, un manifiesto de longitudes y SHA-256 y
un `LEEME.txt`. El paquete es para QEMU; no es una imagen de disco instalable.

| Carpeta o archivo | Responsabilidad |
|---|---|
| `16-bit/` | RESET y transición inicial |
| `32-bit/` | Paginación y entrada a 64 bits |
| `64-bit/diagnostics/` | Diagnóstico de excepciones |
| `64-bit/services/` | Asignación de memoria y sus contratos |
| `64-bit/monitor/` | Órdenes y consola |
| `64-bit/programs/` | Cargador, «Hola mundo» y eco propios |
| `64-bit/screen/` | Vídeo VGA, teclado PS/2 y letras |
| `guardians/` | Límites, reservas y motivos de rechazo |
| `arranque/` | Contrato y siguiente etapa del arranque propio |
| `build-firmware.ps1` | Une los bytes y produce la ROM |

Las etapas siguen llamándose «Faggin scaling», en homenaje a Federico Faggin.
Los nombres internos de perfiles `faggin-16`, `faggin-32` y `faggin-64` se
conservan para mantener reconocibles las pruebas y los registros históricos.
Los nombres de archivos técnicos no se traducen sin necesidad: hacerlo no añade
protección y rompería referencias que ya se verifican.

Las fuentes UEFI anteriores de `src/` son referencias históricas. El camino
actual es firmware propio desde RESET; no se añadirá una entrada `.efi`.

## Estado comprobado y siguiente paso

Hay consola, pantalla, teclado, memoria protegida y dos programas crudos
incluidos en la ROM. QEMU ejecuta esa ROM como firmware de su máquina virtual.
Todavía no es una imagen adaptada a la placa MSI A320M-A PRO MAX y no se
instala copiándola a una carpeta del disco.

El siguiente paso dentro de QEMU es que **nuestro firmware** encuentre programas
en almacenamiento externo, aplicando reglas de selección y validación propias.
Se puede tomar esa organización de UEFI sin implementar sus servicios ni usar
su formato de ejecutable. El alcance está en [Arranque propio](arranque/LEEME.md).
