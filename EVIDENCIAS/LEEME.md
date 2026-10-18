# Evidencias de Orquestador del Metal

## Flappy Metal — juego QEMU y dibujo

[Informes y capturas](FLAPPY_METAL/LEEME.md): escena estática y prototipo jugable
con salto, gravedad, colisiones, puntuación y reinicio. Hay siete comprobaciones
interactivas, siete casos aislados, dos de operandos relativos y tres estáticos.
No se presenta como juego instalado o probado en el hardware real.

## CASM — primera base ejecutable

[Informe CASM](CASM/LEEME.md): compilador escrito en C, verificador de emisión,
39 casos aprobados y ejecución del paquete generado en QEMU/OVMF. Se conserva
la distinción con las fotos del saludo manual en el PC real.

## QEMU — comprobado

Las cuatro capturas originales están en [QEMU](QEMU). Se trasladaron sin cambiar
sus bytes desde Orquestador_Metal/documentacion/capturas; el informe de cierre
apunta ahora aquí. Son pantallas de la máquina virtual, no de la placa física.

| Captura | Qué muestra |
|---|---|
| [01-arranque-gpt.png](QEMU/01-arranque-gpt.png) | Carga automática y saludo desde GPT/FAT32 |
| [02-guardian-gpt.png](QEMU/02-guardian-gpt.png) | Rechazo de cabecera GPT dañada y monitor disponible |
| [03-eco-propio.png](QEMU/03-eco-propio.png) | Escritura con teclado PS/2 y eco propio |
| [04-sin-disco.png](QEMU/04-sin-disco.png) | Motivo de ausencia de disco y retorno al monitor |

[informes](QEMU/informes) conserva la batería aprobada, fuera de build/.
[manifiesto.json](QEMU/manifiesto.json) registra las huellas SHA-256 de fotos e informes.
Para actualizar después de otra batería completa: `./tools/evidence/recopilar-evidencias.ps1`.
El recopilador copia los últimos informes y fotos locales; no vuelve a ejecutar
las pruebas ni certifica que esos archivos no hayan sido editados después.

## PC real — primer saludo mediante puente fotografiado

La [prueba visual de Flappy Metal](PC_REAL/FLAPPY_VISUAL/LEEME.md) ya está instalada
como entrada separada en A: BMO, con archivos verificados y saludo intacto. El usuario
aportó una foto que confirma la escena estática en el PC real. La versión interactiva
y el controlador del teclado USB siguen pendientes.

El usuario reportó éxito en el primer intento físico del puente y aportó
[tres fotos originales](PC_REAL/PRIMER_ARRANQUE/LEEME.md): entrada en el menú,
saludo legible y vista general. El código propio se ejecuta después de
BootServices, con firmware y hardware previamente inicializados por la placa.

[hardware.json](PC_REAL/hardware.json) procede de consultas de solo lectura de
Windows. Confirma la placa, CPU, BIOS, vídeo y controladores enumerados. No
incluye números de serie ni demuestra ejecución del firmware propio en la placa.

La guía [IDENTIFICACION-Y-RECUPERACION](PC_REAL/IDENTIFICACION-Y-RECUPERACION.md)
documenta la preparación para una escritura física. Ya hay una candidata Winbond; la referencia completa y la recuperación siguen pendientes.
Ya hay [fotografías físicas y sus observaciones](PC_REAL/OBSERVACIONES-FOTOS.md). Todavía no hay evidencia de arranque propio desde RESET en Ryzen.

El [plan para llegar al metal](PC_REAL/PLAN-METAL.md) distingue FAT32, GOP y la
inicialización desde RESET. Incluye los criterios que faltan para considerar
terminada una prueba física; las capturas QEMU permanecen separadas.

## Análisis del firmware de fábrica

Ya existe un [primer inventario del firmware MSI 2.C](PC_REAL/analisis-msi/LEEME.md),
para investigar la integración conservando componentes AMD. Es análisis de un
archivo oficial, no una lectura del chip físico ni una modificación instalada.

El destino físico único y el criterio para terminar están en [PERFIL-FISICO](../docs/PERFIL-FISICO.md). QEMU es el banco de pruebas para ese proyecto.

## Puente UEFI → código propio: vía actual de la primera prueba

El usuario aceptó la entrada .efi mínima. Ya hay [capturas e informe de siete casos](PUENTE_UEFI/LEEME.md)
QEMU/OVMF: salida de servicios de arranque, saludo propio en framebuffer y rechazos.
Las capturas de esa carpeta siguen siendo virtuales. La prueba física aportada
por el usuario está en [PC_REAL/PRIMER_ARRANQUE](PC_REAL/PRIMER_ARRANQUE/LEEME.md),
con alcance y huellas separados.
