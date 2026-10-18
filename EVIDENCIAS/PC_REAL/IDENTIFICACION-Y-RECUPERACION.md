# PC real: identificación y recuperación antes del primer RESET propio

Estado: identificación por Windows completada; hay una candidata Winbond en fotos. La referencia completa, el acceso y la recuperación siguen pendientes.
Se mantiene el objetivo de firmware propio desde RESET, sin entrada .efi.
No se ha grabado firmware ni modificado el arranque o discos físicos.

## Equipo observado

Consulta de solo lectura del 18 de octubre de 2026, conservada en hardware.json:

| Elemento | Resultado |
|---|---|
| Placa | MSI A320M-A PRO MAX (MS-7C52), versión 1.0 |
| BIOS instalada | American Megatrends International, 2.C0; fecha reportada 2022-07-22 |
| CPU | AMD Ryzen 5 5600X, seis núcleos, 64 bits |
| Vídeo | NVIDIA GeForce RTX 3060 |
| Almacenamiento enumerado | SATA AHCI y NVMe |
| Chip flash | Candidata Winbond 25Q256JW… fotografiada; sufijo y acceso sin confirmar. Manual MSI: 256 Mbit (32 MiB) |
| Recuperación externa | Usuario indica que aún no dispone de identificación/programador |

La ROM actual inicializa la máquina pc de QEMU: IDE PIIX y VGA emulada. Esa
configuración no es la de esta placa. Hace falta resolver inicio temprano del
Ryzen/chipset/DDR4, un canal de diagnóstico, vídeo y el transporte de almacenamiento.
El lector FAT32 y el formato FAGRAW64 pueden conservarse sobre un transporte nuevo;
no solucionan por sí solos la inicialización física.

## Información física necesaria para escribir (parte ya recibida)

Apagar completamente, desconectar la alimentación de red y seguir las precauciones
de manipulación del manual de la placa antes de inspeccionar. No conectar todavía
un programador ni hacer puentes. No hace falta retirar el chip para identificarlo.

Las fotos recibidas están documentadas en [OBSERVACIONES-FOTOS](OBSERVACIONES-FOTOS.md). La lista siguiente describe qué debe quedar confirmado antes de escribir, no pide repetir todas las tomas:

Obtener fotografías nítidas de:

1. La serigrafía del modelo/revisión y una vista general de la placa.
2. La inscripción completa del posible chip flash, su ubicación y la marca de pin 1.
   Un encapsulado de ocho pines por sí solo no demuestra que sea el chip BIOS.
3. Cualquier cabecera cercana con su serigrafía, sin suponer que expone SPI.

Guardar los originales en EVIDENCIAS/PC_REAL. El marcado debe contrastarse con
la hoja de datos del fabricante: referencia exacta, tensión, capacidad y encapsulado.
Hasta tenerlo no se prescribe programador, adaptador, pinza ni pinout. Un nombre
parecido de chip o un adaptador genérico no establece compatibilidad eléctrica.
Las fotografías físicas requieren una cámara; una captura de Windows no las sustituye.

## Recuperación que debe quedar demostrada

Una vez identificado el chip, documentar el programador y adaptador compatibles,
su tensión y el método de acceso. Verificar si es viable leer en circuito o si la
placa requiere otro procedimiento; evitar alimentar simultáneamente placa y pinza
sin un procedimiento documentado para ese hardware.

Antes de cualquier escritura: obtener al menos dos lecturas completas independientes
con el equipo adecuado, comprobar tamaño y huellas idénticas, y conservar copia
externa del original. Una descarga oficial de MSI puede ser una cápsula de actualización;
no se presupone equivalente a un volcado completo del chip ni que conserve los datos
específicos de esta placa. Lecturas idénticas tampoco prueban por sí solas que la
conexión sea correcta: revisar el contenido y el mapa esperado del chip.

Dejar documentado cómo se restauraría el original con el programador, sin depender
de que el firmware modificado pueda arrancar. No hace falta provocar un fallo para
registrar el procedimiento. La restauración no se considera probada hasta haberla
validado realmente; por ahora figura pendiente.

## Criterio para el primer programa físico

La primera prueba desde RESET deberá producir una señal mínima verificable en
un canal confirmado para la placa; no empezar por exigir FAT32, teclado y RTX.
Después: inicialización de memoria, entrada en 64 bits y pruebas de memoria;
finalmente controladores y carga externa. Mantener estas etapas separadas evita
atribuir a FAT32 un fallo anterior de RAM o dispositivo.

Hoy no existe en este proyecto una imagen arrancable desde RESET para MS-7C52.
No se ha demostrado aquí un port compatible que podamos reutilizar. El objetivo
no se resuelve renombrando la ROM ni copiándola al USB. Tampoco se ha elegido
un arranque CSM o un puente .efi: esas rutas delegarían el inicio en el firmware
instalado y serían una prueba distinta de la que se ha solicitado.

## Fuentes consultadas

[Especificaciones MSI de la placa](https://www.msi.com/Motherboard/A320M-A-PRO-MAX/Specification):
chipset, memoria, almacenamiento y conectores físicos. La revisión observada se
obtiene del inventario local; no se inventa la ubicación del chip a partir de la ficha.

[FAQ de coreboot](https://doc.coreboot.org/getting_started/faq.html): la inicialización
de hardware es distinta de la carga del programa y el soporte Ryzen tiene límites.
Esa documentación no demuestra soporte de esta combinación MS-7C52/5600X.
