# Orquestador y primer juego: alcance y orden

## Objetivo

Ejecutar un juego pequeño tipo Flappy Bird como un único programa propio en el
perfil MSI A320M-A PRO MAX + Ryzen 5 5600X, con pantalla inicializada por el
firmware y código propio después de ExitBootServices. El primer destino de
desarrollo será QEMU; la copia física requiere una versión comprobada.

No hace falta un kernel como archivo separado: el programa integra el bucle de
eventos, memoria, entrada y dibujo que necesita. Esas son responsabilidades de
sistema aunque estén dentro del juego. FAT32 transporta archivos; no ejecuta ni
enseña nuevas capacidades físicas a la CPU.

## Punto de partida comprobado

- Saludo manual fotografiado en el equipo real después de BootServices.
- CASM 0.1 implementado en C, con constantes de texto, llamadas a metal_puts,
  retorno, emisión HEX, verificación estructural y paquete FAGRAW64.
- 39 casos CASM aprobados y saludo generado ejecutado en QEMU/OVMF.

Ya hay [una primera escena estática](../Games/Flappy_Metal/README.md) con 38
rectángulos y tres pruebas QEMU aprobadas. El dibujador está escrito en .hex y
todavía no es una operación de CASM. No hay aritmética CASM, reloj, teclado real después
de BootServices ni soporte multiprocesador propio. El cuerpo cargable actual
está limitado a 4072 bytes. El juego no se presenta como implementado.

## Etapas con criterio de aceptación

| Etapa | Trabajo concreto | Cómo se acepta |
|---|---|---|
| 1. Contrato propio | Versionar el ABI; documentar registros, memoria, pila y servicios permitidos; instalar excepciones propias antes de habilitar eventos | Error intencional muestra motivo y se detiene de forma definida en QEMU |
| 2. CASM numérico | Enteros, locales, asignación, comparaciones, if y bucles; reglas explícitas de inicialización, overflow y límites | Casos válidos ejecutados y casos inválidos rechazados por ambos controles cuando corresponda |
| 3. Dibujo CPU | Primera escena .hex lista y probada; falta exponer un ABI gráfico versionado a CASM | Ya hay píxeles exactos y rechazos de overflow/ancho cero; falta integración con el lenguaje |
| 4. Tiempo | Detectar un reloj disponible; definir unidades, calibración y avance de simulación a paso fijo | La velocidad del juego no depende del número de iteraciones por segundo |
| 5. Entrada | QEMU primero; después identificar y soportar el controlador del teclado real | Una pulsación cambia el estado; pulsar/mantener/soltar tiene comportamiento definido |
| 6. Juego | Personaje rectangular, gravedad, impulso, obstáculos, colisión, puntuación y reinicio | Sesión QEMU jugable y repetible con pruebas de colisiones y límites |
| 7. Primera prueba del juego en PC | Congelar paquete y huellas; copiarlo solo tras revisar su resultado QEMU | Foto/vídeo real y registro de la versión, controles y resultado |

El teclado simulado no sustituye al controlador real: un teclado USB puede
necesitar xHCI, enumeración USB e HID. No se presupone que el firmware conserve
servicios de teclado después de ExitBootServices. La adaptación puede ser una
parte mayor que el propio juego; debe evaluarse antes de prometer plazos.

Si el programa supera 4072 bytes, se debe cambiar conjuntamente el contrato de
paquete, las reservas del cargador, los límites CASM, el verificador y las pruebas.
No se elimina el guardián de tamaño para hacer pasar una compilación.

## Mochila FAT32 para la primera versión

La estrategia inicial es cargar todos los recursos necesarios antes de salir de
BootServices y conservarlos en RAM con límites y longitudes verificadas. El primer
juego puede usar rectángulos y colores generados, sin imágenes externas.

Leer archivos nuevos después de salir requiere un controlador de almacenamiento
y lector FAT32 propios para ese transporte. El lector de la ROM QEMU no demuestra
soporte del SSD SATA o NVMe real. No es requisito para el primer juego precargado.

## Más adelante: tareas y mediciones

Primero un núcleo y un bucle de juego simple. Después se pueden medir tiempo de
simulación, dibujo y espera. Solo si las mediciones lo justifican se estudiarán
colas de tareas, otros núcleos o selección de estrategias basada en resultados.
No existe todavía un sistema de aprendizaje, planificador propio ni backend GPU.
Escribir píxeles con CPU en el framebuffer no es ejecutar código en la GPU.

## Relación con LLVM y GCC

CASM explora un compilador especializado, un ABI pequeño y emisión inspeccionable.
La compilación y la organización de tareas no son ideas exclusivas del proyecto.
No hay mediciones ni demostración técnica para afirmar que reemplaza o supera
LLVM/GCC. Clang sigue siendo la herramienta que compila el compilador anfitrión.
La aportación concreta actual es el contrato propio y su recorrido comprobable,
no una afirmación de ruptura de toda la compilación existente.

## Orden de carpetas y limpieza

| Carpeta | Papel |
|---|---|
| CASM | Lenguaje, compilador, verificador y pruebas; documentación técnica en inglés |
| Puente_Metal | Entrada UEFI y entrega al código propio |
| Orquestador_Metal | ROM desde RESET y servicios de la plataforma QEMU |
| EVIDENCIAS | Resultados y fotos conservados, separados por procedencia |
| Games/Flappy_Metal | Primera escena y sus comprobaciones de dibujo |
| tools | Utilidades agrupadas por construcción, pruebas, QEMU, instalación y análisis |
| docs | Perfil físico y este plan |
| src | Ejemplos históricos; se conservan para referencia |
| build | Salidas regenerables, imágenes virtuales, herramientas y análisis locales |

`clean-workspace.ps1` muestra una limpieza conservadora; `-Apply` la aplica.
Conserva la última ejecución CASM y elimina antiguas solo si sus cinco archivos
coinciden. También elimina cachés y copias virtuales de pruebas negativas; no
borra evidencias, fuentes, referencias MSI, imágenes principales ni el SSD A:.
Las imágenes negativas se regeneran con `iniciar-puente.ps1 -Comprobar`.
