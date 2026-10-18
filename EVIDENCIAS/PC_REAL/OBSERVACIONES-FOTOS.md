# Primeras fotografías físicas recibidas

Recibidas el 18 de octubre de 2026. Los tres originales y sus huellas están en
[fotos](fotos/). Son evidencias de identificación visual del equipo; no de ejecución
del firmware propio. No se han editado ni recortado.

## Observaciones que sí permiten

- Se lee A320M-A PRO en la serigrafía visible. La variante MS-7C52/MAX se mantiene
  como identificación reportada por Windows; estas fotos no muestran una nueva
  lectura completa de modelo y revisión que la sustituya.
- Se ve un SSD M.2 Kingston NV2 con etiqueta de 1 TB. Ese módulo es almacenamiento,
  no el chip flash del firmware de la placa.
- Se ve la tarjeta GeForce RTX y el disipador/ventilador del procesador.
- La primera y tercera foto permiten orientar la placa usando pila, M.2 y puertos.
  La segunda amplía la serigrafía y el SSD, no una inscripción de chip BIOS legible.

## Información que todavía falta

No se identifica de forma fiable el chip flash ni se lee su marcado. No se
asignan fabricante, capacidad, voltaje o pinout a partir de AM4 o A320. AM4
identifica el zócalo del procesador y A320 el chipset; ninguno determina por sí
solo qué memoria flash monta esta unidad concreta.

En estas tomas parte de la placa queda fuera de encuadre u oculta por componentes.
Primero hace falta una vista más amplia de la mitad inferior y borde inferior de
la placa, con los puertos traseros a la izquierda como orientación. No se señala
un chip concreto mientras no se distinga. Después se pedirá un acercamiento al
componente candidato para leer todas sus líneas y su marca de orientación.

Hacer las nuevas tomas con el equipo apagado y desconectado de la red, sin tocar
la placa ni conectar herramientas durante funcionamiento. El ventilador aparece
borroso en las fotos; no se deduce con certeza el estado de alimentación de una
imagen fija. No es necesario retirar de entrada la GPU o el disipador para
solicitar esta vista general.

## Referencia visual del fabricante

[Foto y ficha oficial MSI A320M-A PRO MAX](https://storage-asset.msi.com/datasheet/original/mb/global/A320M-A-PRO-MAX.pdf)
permite comparar la distribución general. No es una hoja de datos del chip flash
ni garantiza que una referencia de memoria concreta esté montada en esta placa.

## Segunda tanda: fotos 04..06

El componente de ocho patillas en 05 permite leer tentativamente NIKOS y una
referencia que empieza por P0603. El sufijo no se transcribe como confirmado.
Esa lectura apunta a un MOSFET, no a memoria flash; no se da por identificado
el chip BIOS. [VBsemi documenta P0603BVG como MOSFET](https://www.vbsemi.com/index.php?id=141030),
pero su variante no demuestra por sí sola el modelo exacto fotografiado.
Los componentes centrales de 04 y 06 tampoco muestran una inscripción legible
que permita identificarlos como memoria BIOS. Hace falta una vista de contexto
más amplia para ubicar los candidatos antes de insistir con otro macro.
