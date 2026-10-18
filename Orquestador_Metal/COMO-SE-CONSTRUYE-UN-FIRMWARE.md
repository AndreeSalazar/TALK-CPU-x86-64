# Como se construye un firmware: referencia para Faggin scaling

Esta explicación es una referencia de arquitectura. El proyecto tiene un único
destino físico: MS-7C52 con Ryzen 5 5600X, según [PERFIL-FISICO](../docs/PERFIL-FISICO.md).
La v1 QEMU está terminada; la adaptación investiga conservar componentes AMD y el
entorno de inicio que requieran. No se busca implementar toda la especificación
UEFI ni soportar otras placas. El [trazado actual](../EVIDENCIAS/PC_REAL/analisis-msi/TRAZADO-Y-ENTREGA.md)
documenta las dependencias reales encontradas en la referencia MSI.

## De EFI a UEFI

EFI fue desarrollado inicialmente por Intel. En 2005 se anuncio el UEFI
Forum para continuar la evolucion de esa especificacion con participacion
de varias empresas. La idea era definir una interfaz comun entre firmware
y programas de arranque, para mejorar la interoperabilidad entre plataformas.
[Anuncio original del UEFI Forum, 25 de julio de 2005](https://uefi.org/press-release/UEFI_Forum_to_Manage_Key_Firmware_to_Operating_System_Specification_July_25_2005).

UEFI define interfaces y comportamientos, no un unico firmware universal.
Un ejecutable .efi contiene codigo de maquina y cabeceras de imagen, y se
ejecuta dentro del entorno que ofrece el firmware. En x64 usa PE32+.
El firmware carga sus secciones, ajusta direcciones y llama a la entrada.
La extension no es una instruccion del procesador.
[UEFI: imagenes, carga y servicios](https://uefi.org/specs/UEFI/2.11/02_Overview.html).

## Dos capas que conviene distinguir

UEFI describe la interfaz externa del firmware. Platform Initialization
(PI) describe interfaces entre sus componentes internos. SEC, PEI y DXE
pertenecen a esa arquitectura; no son nombres para los modos de 16, 32
y 64 bits. Implementar exactamente PEI y DXE no es un requisito para ofrecer
la interfaz UEFI. Para Faggin scaling podemos inspirarnos en sus
responsabilidades sin copiar esas fases ni declarar compatibilidad UEFI.
[TianoCore: distincion entre UEFI y PI](https://www.tianocore.org/tianocore-wiki.github.io/reference/specs-standards/pi.html).

## Orden habitual en una implementacion PI

| Fase | Trabajo principal | Relacion con nuestro proyecto |
| --- | --- | --- |
| SEC | Primer estado de ejecucion, entorno temporal y entrega a la siguiente fase | Nuestro reset, segmentos, pilas y cambios de modo cubren parte del arranque temprano |
| PEI | Preparar memoria permanente y describir recursos para la siguiente fase | QEMU ya ofrece RAM utilizable; probamos una region, sin inicializar DDR4 |
| DXE | Inicializar componentes y ofrecer servicios mediante drivers y protocolos | QEMU ya tiene servicios de memoria y dispositivos propios; la integración física sigue pendiente |
| BDS | Elegir el destino de arranque y preparar los dispositivos necesarios | QEMU ya busca y carga METAL/INICIO.X86 desde FAT32; falta el transporte físico |
| Runtime | Servicios que siguen disponibles despues de la entrega del control | No implementado ni necesario para la prueba actual |

Es una comparacion de responsabilidades, no una equivalencia funcional.
El flujo PI normal avanza por SEC, PEI, DXE y BDS antes del entorno de runtime.
[UEFI PI: flujo de arranque](https://uefi.org/specs/PI/1.8/V1_Boot_Paths.html).
La preparacion PEI incluye memoria permanente e informacion de entrega en
Hand-Off Blocks (HOBs).
[UEFI PI: objetivos de PEI](https://uefi.org/specs/PI/1.8/V1_Overview.html).

## Un ejemplo abierto: OVMF

OVMF es una implementacion para maquinas virtuales basada en EDK II.
Su recorrido documentado comienza con un vector de reset y transiciones
de modo. Despues localiza componentes del firmware, ejecuta PEI y DXE,
y llega a la seleccion de arranque. La colocacion concreta del cambio a
64 bits depende de la configuracion de sus fases.

Para estudiar su organizacion, la documentacion senala:

- UefiCpuPkg/ResetVector: entrada y transiciones de modo.
- OvmfPkg/Sec: nucleo temprano que encuentra PEI.
- MdeModulePkg/Core/Pei: infraestructura PEI.
- MdeModulePkg/Core/Dxe: infraestructura DXE.

La documentacion de algunas partes refleja versiones anteriores de EDK II;
los nombres de componentes BDS y su ubicacion pueden cambiar. Este proyecto
no incorpora su codigo: usamos su arquitectura como referencia.
[TianoCore: recorrido de arranque de OVMF](https://www.tianocore.org/tianocore-wiki.github.io/platforms-packages/platform-ports/ovmf_boot_overview.html).

## Orden de desarrollo propuesto para nuestro firmware

1. **Entrada y modos:** reset -> 16 -> 32 -> 64 bits. Implementado y probado.
2. **Prueba sostenida de RAM:** patrones dependientes de direccion, lectura
   en ambos sentidos y deteccion de corrupcion provocada. Implementado en
   64-bit/stress. Comprueba 1 MiB; no descubre toda la memoria ni sustituye
   una prueba de memoria fisica.
3. **Excepciones:** IDT y TSS instaladas en 64 bits, con diagnostico terminal
   y pilas IST para eventos criticos. Cinco clases de fallo comprobadas
   mediante nueve casos, incluidos limites de memoria y un cruce de pila.
   Faltan cobertura temprana de 16/32 bits y recuperacion de errores.
4. **Recursos de plataforma:** reservas fijas, presupuesto ROM y guardianes
   implementados. Falta descubrir dinamicamente la memoria disponible.
5. **Servicios propios:** asignador lineal limitado a 512 KiB, con ABI y
   tabla versionada propios, y once autopruebas ejecutadas en 64 bits.
   El ABI v2 incorpora complemento de cursor y bloqueo persistente con motivo.
   El diagnostico tambien es propio. Faltan servicios de dispositivos.
6. **Controladores:** descubrir y controlar dispositivos concretos de QEMU,
   sin delegar las operaciones en firmware UEFI.
7. **Ejecucion de otros binarios, si se necesita:** definir un formato propio,
   validarlo, cargarlo y entregar el control con un contrato explicito.

Regla transversal ya implementada: `guardians/` asigna ventanas, reservas,
presupuestos y semaforos. Las paginas de guarda, NX y escritura protegida
se aplican por hardware virtual desde la activacion de paginacion. Las
comprobaciones estructurales detienen la construccion si hay cruces.

Primera compactacion manual comprobada: ver `COMPACTACION.md`. Se mantienen
los .hex, con 71 bytes explicitos menos y las mismas comprobaciones aprobadas.

Estos pasos construyen firmware; no requieren desarrollar un sistema operativo.
Una implementacion que quiera llamarse compatible con UEFI tendra que satisfacer
sus requisitos de interfaz. Usar nuestra propia interfaz permite otro diseno.

## Lo que no demuestra la prueba

Cambiar de modos y comprobar RAM no equivale a sustituir todas las funciones
de un firmware comercial. Nuestra prueba usa la plataforma emulada por QEMU,
con memoria y dispositivos conocidos. Tampoco modifica el firmware del equipo
anfitrion. Adaptar el nucleo a otra placa requiere una capa de plataforma
especifica y comprobar sus condiciones de inicializacion.
