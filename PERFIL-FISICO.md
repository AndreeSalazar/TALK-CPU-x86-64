# Un solo perfil físico: mi PC

Decisión del proyecto, 18 de octubre de 2026: desarrollar Orquestador del Metal
para este equipo concreto. QEMU es el banco de pruebas; no es otro objetivo
comercial. No se pretende implementar UEFI completo ni soportar todas las placas.

## Equipo de referencia

| Elemento | Identificación y alcance |
|---|---|
| Placa | MSI A320M-A PRO MAX, MS-7C52; versión 1.0 reportada por Windows |
| Procesador | Ryzen 5 5600X; Family 25 Model 33 Stepping 2 reportado por Windows |
| Ejecución propia inicial | x86-64 en el núcleo de arranque; sin objetivo de multiprocesamiento propio en esta entrega |
| Memoria | DDR4 instalada en esta unidad; conservar la configuración e inicialización de plataforma que requiera |
| Vídeo | GeForce RTX 3060 observada; saludo real fotografiado en framebuffer obtenido con GOP; sin driver NVIDIA propio |
| Almacenamiento de referencia | Kingston NV2 NVMe de 1 TB fotografiado; controlador físico aún sin integrar |
| Firmware usado para investigar | MSI 2.C, miembro E7C52AMS.2C0, 32 MiB; no es un volcado del chip instalado |
| Flash física candidata | Winbond 25Q256JW…; falta confirmar sufijo, encapsulado y acceso compatible |

Cambiar placa, CPU o controladores requiere revisar este perfil: no se anuncia
compatibilidad por compartir AM4. USB no añade un segundo perfil de placa, pero
sí requiere otro transporte; no se promete soporte USB en la primera integración.
El SSD de referencia no queda autorizado para formateo, borrado ni escritura de
prueba por aparecer en esta tabla.

## Estrategia de firmware desde RESET (investigación conservada)

Conservar los componentes AMD necesarios e investigar qué entorno de inicio
requieren. Los datos y código conservados siguen siendo de sus fabricantes;
las instrucciones propias permanecen escritas a mano en .hex. Los scripts Python
y PowerShell son herramientas del anfitrión para analizar y construir archivos.

En esta vía de investigación desde RESET no se usa una aplicación .efi de entrada. Conservar
componentes AMD puede exigir conservar o proporcionar fases internas PI/UEFI y
partes de AMI. Por eso no se afirma que la futura imagen carezca de todo código
UEFI. La integración aún no está implementada ni se ha demostrado su viabilidad
completa para esta placa. Reutilizar binarios no equivale a disponer de una API
de inicio independiente ni de permiso automático para redistribuirlos.

El propósito es aprender cómo arranca este PC y conseguir que nuestro código
controle su ejecución después del inicio de plataforma, con una entrada desde
el firmware del equipo y sin depender de una aplicación .efi del disco.

## Vía actual aceptada: puente .efi → código propio

Para la primera prueba real el usuario autorizó una entrada .efi mínima. El puente
usa el firmware instalado para reservar memoria, leer el paquete y obtener GOP;
sale de los servicios de arranque y ejecuta el cuerpo propio con servicios de
pantalla propios. Conserva el hardware ya inicializado y no depende de completar
el port MSI desde RESET. No se afirma que elimine runtime, SMM o el PSP.

El prototipo funciona en QEMU/OVMF y pasó siete casos. El usuario reportó éxito
en el primer intento físico y aportó [fotos](EVIDENCIAS/PC_REAL/PRIMER_ARRANQUE/LEEME.md).
La primera entrega es el saludo y el retorno al bucle HLT; teclado/eco y el monitor completo después de salir
siguen pendientes. [Guía y límites](Puente_Metal/LEEME.md).

## Qué significa terminar la adaptación desde RESET

La entrega física se cerrará cuando este equipo arranque de forma repetible con
una imagen adaptada, alcance el código propio de 64 bits, muestre texto en su
pantalla y permita el saludo y el eco. La carga externa debe encontrar y validar
METAL/INICIO.X86 en FAT32 mediante un transporte físico comprobado y devolver un
motivo de rechazo cuando corresponda. Las fotos y registros deben proceder del
PC real y quedar en EVIDENCIAS/PC_REAL, con versión y huellas de la imagen usada.

Antes de una escritura física deben estar disponibles el original de esta unidad
y su recuperación externa. Una imagen oficial sirve para análisis, no reemplaza
por sí sola ese respaldo. El constructor permanece bloqueado para MS-7C52 hasta
que haya fuentes, contratos y comprobaciones específicos de la integración.

No forman parte de este cierre: otras placas/CPU, implementación íntegra de UEFI,
aceleración 3D, catálogo universal de controladores, escritura FAT32, SMP propio
ni promesas de arranque en cualquier SSD o USB.

## Estado actual verificable

| Parte | Estado | Evidencia |
|---|---|---|
| Puente .efi hacia código propio | Siete casos QEMU/OVMF; primer éxito físico reportado y fotografiado | [Fotos reales](EVIDENCIAS/PC_REAL/PRIMER_ARRANQUE/LEEME.md) |
| Firmware propio QEMU | Terminado para su plataforma | [Cierre v1](Orquestador_Metal/CIERRE-v1.md) |
| Fotografías e identificación de este PC | Recibidas; chip candidato localizado | [Observaciones](EVIDENCIAS/PC_REAL/OBSERVACIONES-FOTOS.md) |
| Inventario MSI y trazado AMD/PEI | Implementados; 5 + 11 comprobaciones aprobadas | [Trazado](EVIDENCIAS/PC_REAL/analisis-msi/TRAZADO-Y-ENTREGA.md) |
| Ruta exacta activa del 5600X y entrega a código propio | Pendientes de demostrar | [Análisis](EVIDENCIAS/PC_REAL/analisis-msi/LEEME.md) |
| Imagen física modificada, respaldo y restauración | Pendientes | [Identificación y recuperación](EVIDENCIAS/PC_REAL/IDENTIFICACION-Y-RECUPERACION.md) |
| Entrada EFI desde FAT32 físico y saludo propio en pantalla | Primer éxito reportado; no acredita transporte propio tras salir de BootServices | [Fotos reales](EVIDENCIAS/PC_REAL/PRIMER_ARRANQUE/LEEME.md) |
| Arranque desde RESET con imagen adaptada a la placa | Pendiente | Investigación separada del puente |

## Trabajo que falta, acotado a este equipo

1. Resolver la selección y las dependencias de inicio para el 5600X; definir el
   estado de CPU, RAM y dispositivos que recibirá el código propio.
2. Implementar esa entrega y adaptar pantalla, entrada y un transporte de
   almacenamiento de este perfil, sin ampliar a una colección de hardware.
3. Comprobar la imagen candidata y preparar el original y su recuperación;
   realizar después la prueba física y registrar sus evidencias.

La documentación y el alcance quedan definidos. La vía actual de primera prueba es el puente; el port desde RESET sigue abierto como investigación separada;
un análisis aprobado no lo convierte en una imagen lista para grabar.
