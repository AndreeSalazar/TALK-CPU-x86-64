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

## Tercera tanda: fotos 07..08

En 07 se lee RT8894A: [Richtek lo identifica como controlador PWM de alimentación
para CPU AMD SVI2](https://www.richtek.com/en/Products/Vcore/Vcore%20Controller/RT8894A).
En 08 se lee RTL8111H: [Realtek lo identifica como controlador Ethernet
10/100/1000](https://www.realtek.com/Product/Index?cate_id=786&id=3959&menu_id=1006).
Ninguno es la memoria flash BIOS buscada. Ambas inscripciones son útiles para
el inventario físico; la ubicación del chip flash sigue sin confirmarse.

## Cuarta tanda: candidata Winbond en foto 10

En 10 se distingue Winbond y una referencia compatible visualmente con
25Q256JW…; la transcripción del sufijo completo aún no se da por definitiva.
Es una candidata clara a la memoria flash buscada: la familia W25Q256JW es
QSPI NOR de 256 Mbit (32 MiB), consistente con la capacidad del manual MSI.
La función precisa como almacén BIOS de esta unidad requiere corroborar el
contexto físico y/o el contenido leído; no se ha leído ni programado.

[Winbond W25Q256JW](https://www.winbond.com/hq/product/code-storage-flash-memory/serial-nor-flash/?__locale=ja&partNo=W25Q256JW)
especifica 1,7..1,95 V y opciones WSON8, SOP16 y BGA. Si se confirma JW, se
trataría de la familia de 1,8 V. No se prescribe un voltaje basándose únicamente
en la capacidad o en esta lectura parcial. El encapsulado exacto tampoco se
da por cerrado. El esquema de ocho patillas salientes mostrado en el chat era
solo una ilustración; una flash puede tener contactos inferiores sin patillas
laterales accesibles a una pinza habitual.

La foto 09 muestra NIKOS P5003QVG; no es la candidata Winbond. Se conservan
ambos originales. Por ahora no se solicitan más fotografías para buscar otros
componentes: primero revisar esta candidata y su forma de acceso.
