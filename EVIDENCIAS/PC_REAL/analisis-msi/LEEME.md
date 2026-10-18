# Primer mapa del firmware oficial MSI: conservar componentes AMD

Análisis del 18 de octubre de 2026. Decisión: investigar firmware propio desde
RESET conservando componentes AMD necesarios; sin entrada .efi en USB.
Esta entrega es un inventario offline, no una imagen modificada ni instalable.

## Referencia exacta

Se descargó desde el dominio oficial MSI el paquete
[7C52v2C.zip](https://download.msi.com/bos_exe/mb/7C52v2C.zip), para A320M-A PRO MAX.
El archivo de notas incluido identifica MS-7C52 V2.C y fecha 2022/07/25; anuncia
AGESA ComboAm4v2PI 1.2.0.7. Windows reportó 2.C0, con otra fecha SMBIOS. Eso permite
comparar la misma versión nominal; no prueba igualdad byte a byte con el chip instalado.

| Elemento | Valor |
|---|---|
| Miembro del ZIP | 7C52v2C/E7C52AMS.2C0 |
| Tamaño de imagen | 33554432 bytes (32 MiB) |
| SHA-256 del ZIP | FCE8FAAC05AA2E73752E946DA7A4171CB4D9DEF4B3AB561D835286129DC5B961 |
| SHA-256 de imagen | 6985798091e83a7c7619be1b3a03db60d293352c17261fccac52a1634495da4d |

Las huellas son las observadas en esta descarga, no una firma digital verificada
ni valores publicados por MSI. Los binarios originales permanecen en build/analisis-msi,
fuera de Git; los informes sí se conservan en esta carpeta.

## Hallazgos comprobados

- 18 tablas AMD PSP/BIOS, niveles 1 y 2, con límites y Fletcher-32 correctos.
- 10 cabeceras de volumen de firmware con límites y checksum de cabecera correctos.
  Algunas están anidadas: no representan diez regiones independientes ni diez BIOS.
- 289 archivos FFS visibles con cabecera comprobada; 151 nombres visibles distintos.
  No se descomprimieron secciones. Puede haber archivos adicionales no inventariados.
- Entre los nombres visibles: AmdSocAm4VmrPei, AmdCcxZen3Pei, AmdMemAm4SspPei,
  AmdPspPeiV2Ssp, AmdVersionPei y AmiAgesaPei. Son etiquetas leídas de secciones UI;
  no prueban ejecución, ausencia de alteraciones ni la selección activa en un 5600X.

[inventario.json](inventario.json) contiene offsets, entradas, GUID, nombres y
huellas de rangos AMD que el analizador pudo resolver dentro de la imagen.
Una entrada no resuelta no implica automáticamente corrupción: hay valores,
reservas y modos de direccionamiento que este primer analizador no interpreta.
Tampoco se ha seguido la selección combo por ID de procesador hasta una ruta activa.

La presencia de varios módulos generacionales confirma que necesitamos seguir
la ruta concreta del procesador, no extraer cualquier componente que diga AMD.

## Qué cambia para nuestro proyecto

Tenemos evidencia de los componentes de inicio que contiene la referencia oficial.
Aún no tenemos una biblioteca independiente lista para llamar desde nuestros .hex.
Los módulos PEI dependen de servicios, interfaces, orden de ejecución, memoria y
estado de plataforma. El siguiente contrato debe describir quién prepara cada
recurso y qué estado recibe Orquestador del Metal después de esa inicialización.

Conservar partes AMD es una estrategia de integración por investigar. Este mapa
no demuestra que podamos separar esas partes de AMI/UEFI y sustituir su entorno.
También falta determinar qué límites de firma y cobertura afectan a cada componente;
los checksums comprobados aquí no responden esa pregunta.

## Próxima secuencia con resultados verificables

1. Resolver las tablas combo y la selección para Vermeer/5600X; contrastar las
   relaciones de directorios con herramientas mantenidas de AMD/coreboot.
2. Analizar dependencias de los módulos PEI y sus entradas. Documentar qué entorno
   requieren los componentes que conservaríamos y si existe una integración viable.
3. Definir la entrega a nuestro código: modo de CPU, RAM disponible/reservada,
   tablas y dispositivos ya inicializados. La ROM QEMU no se injerta sin adaptar.
4. Construir y comprobar esa integración en archivos separados. Mantener el bloqueo
   de plataforma mientras no haya un port real y una vía de recuperación preparada.
5. Antes de cualquier escritura física, obtener el volcado original de esta unidad,
   confirmar chip/encapsulado/voltaje y el método de restauración. La descarga MSI
   no sustituye los datos particulares del chip instalado.

No hay aún un SSD/USB FAT32 capaz de reemplazar el inicio desde RESET de esta placa.
El lector FAT32 y el cargador siguen siendo piezas propias reutilizables después
de resolver inicio y controladores. GOP de la BIOS de fábrica tampoco se presupone
presente en una integración que sustituya ese entorno.

## Reproducir sin modificar firmware

Desde la raíz, con Python 3 disponible:

```powershell
.\tools/analysis/analizar-msi.ps1 -Descargar
```

Para repetir sobre el ZIP local, omitir -Descargar. Se admite -Python con la ruta
del intérprete. El script comprueba la huella fijada de la referencia, lee el ZIP
sin extraer sus rutas al disco y escribe informes bajo build/analisis-msi.
La utilidad es código del anfitrión; no cambia la política de instrucciones .hex
manuales del firmware. No produce código de CPU, no parchea módulos ni llama a un
programador o actualizador BIOS.

[pruebas.json](pruebas.json): cinco comprobaciones aprobadas. Las pruebas alteran
copias en RAM para rechazar una tabla con cambios, una truncada, un conteo excesivo
y una cabecera FV dañada; también verifican que el ZIP original conserva su huella.
La batería QEMU previa no se repitió: no se modificaron sus instrucciones ni su ROM.

## Referencias técnicas

[coreboot: integración PSP](https://doc.coreboot.org/soc/amd/psp_integration.html)
describe estructuras y tipos de componentes. Para detalles de Fletcher-32 y
límites se contrastó [amdfwtool](https://github.com/coreboot/coreboot/tree/main/util/amdfwtool).
La documentación genérica no sustituye la selección específica de Vermeer.

[UEFI PI: almacenamiento de firmware](https://uefi.org/specs/PI/1.8A/V3_Code_Definitions.html)
describe FV, FFS y secciones. Es referencia de formato, no una aceptación de usar
una aplicación .efi como vía de arranque de nuestro proyecto.

## Segunda entrega del análisis

El [trazado AMD y las dependencias PEI](TRAZADO-Y-ENTREGA.md) sigue los enlaces con
contexto de dominio y reemplaza la resolución simplificada de direcciones de este
primer inventario para cualquier decisión de integración. Incluye 11 comprobaciones
nuevas y la identificación de PPIs de variables, configuración PCD y SMBus.
