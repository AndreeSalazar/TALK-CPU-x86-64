# Puente al Metal: UEFI mínimo → código propio

Decisión aceptada por el usuario el 18 de octubre de 2026: usar una entrada .efi
mínima para la primera prueba física y abandonar los servicios de arranque antes
de ejecutar el programa propio. Este camino ya no requiere reemplazar el chip BIOS.
El firmware desde RESET para QEMU se conserva; el port MSI desde RESET es investigación
separada y no bloquea esta prueba del puente.

## Qué hace y qué se comprobó

1. UEFI carga nuestra aplicación PE32+ x64. Su cabecera e instrucciones están en .hex.
2. Se reservan 128 KiB de LoaderData y una página LoaderCode mediante UEFI.
3. Se obtiene el modo GOP activo y se comprueban dimensiones, formato y tamaño.
4. Se abre el mismo volumen del .efi y se lee METAL/INICIO.X86 (hasta 4097 bytes).
5. Se valida FAGRAW64: firma, longitud 1..4072, entrada, flags, suma y tamaño total.
   Solo después se copia el cuerpo a la página de código.
6. Tras cerrar archivos se obtiene el mapa de memoria y se llama ExitBootServices.
   INVALID_PARAMETER permite tres intentos como máximo, renovando el mapa.
7. Solo con éxito se establece la pila propia, se dibuja directamente en el framebuffer
   y se llama al programa. El ejemplo retorna y el procesador se detiene con HLT.

La prueba QEMU/OVMF verificó estado final, código copiado exacto, memoria reservada,
CPL=0 y los píxeles de las tres líneas. También pasó cinco rechazos de archivo/paquete
y un fallo de MapKey inyectado solo en la imagen de prueba. Total: siete casos.
El [informe y las capturas](../EVIDENCIAS/PUENTE_UEFI/LEEME.md) describen sus límites.

## Cómo verlo ahora

Desde la raíz:

```powershell
.\iniciar-puente.ps1
```

Usa QEMU instalado y sus archivos OVMF; no cambia el firmware del PC. Acepta -Qemu
y -Python si las rutas instaladas son diferentes. Para las siete comprobaciones:

```powershell
.\iniciar-puente.ps1 -Comprobar
```

El texto esperado es:

```text
METAL64: BootServices cerrados.
Hola mundo desde mi .hex!
Programa propio retorno. CPU detenida.
```

La pantalla después de salir de UEFI la dibujan nuestras instrucciones. No se usa
OutputString ni GOP.Blt en esa fase. UEFI dejó inicializada la GPU: conservar ese
framebuffer no equivale a implementar un controlador NVIDIA ni aceleración 3D.
No se eliminan los servicios runtime, SMM ni los componentes AMD de la plataforma.

## Archivos para la primera prueba física

**Instalado en A: BMO el 18 de octubre de 2026**, con la entrada separada
**Orquestador del Metal (prueba)** al final del orden previo. Las huellas de ambos
archivos se verificaron. Aún falta el arranque físico y su foto: consulta el
[registro de instalación y pasos](../EVIDENCIAS/PC_REAL/PUENTE_INSTALADO/LEEME.md).

`./construir-puente.ps1` genera:

```text
build/Puente_Metal/
  EFI/BOOT/BOOTX64.EFI   12288 bytes: entrada UEFI propia
  METAL/INICIO.X86      64 bytes: hola mundo FAGRAW64 propio
  manifiesto.json       longitudes y SHA-256
```

BOOTX64.EFI es la ruta de medios extraíbles. En el SSD interno A: se prepara una
ruta separada EFI/ORQUESTADOR/METAL.EFI para conservar las entradas anteriores.
El cargador usa el dispositivo del que se inició, no una letra Windows.

El copiado comprueba FAT32, rechaza una partición de sistema/Windows y conserva
copias con huellas si ya hay archivos en las rutas destino. No formatea ni cambia
el tipo GPT. En PowerShell con permisos suficientes, una vez elegido el volumen:

```powershell
.\copiar-puente.ps1 -Destino A:\
.\registrar-puente.ps1 -Destino A:\
```

La segunda utilidad crea una entrada separada Orquestador del Metal (prueba), la
coloca al final y comprueba que el orden anterior siga intacto. No reinicia ni
selecciona esa entrada por defecto. Registra el identificador y cómo retirarla.
Si falla después de crearla, retira solo la entrada nueva y restaura el orden
anterior. No modifica Windows Boot Manager ni sus archivos. No debe confundirse
una creación de entrada con una prueba de arranque físico completada.

Para un USB que Windows identifique como extraíble se usa -Extraible al copiar,
y se selecciona su entrada UEFI desde F11; no requiere registrar una opción del
SSD. No se incluye ninguna operación de formateo. No se aplica esa opción al SSD A:.

La lectura actual indica Secure Boot desactivado en Windows. El prototipo está
sin firmar; si estuviera activo, el registro se detiene y no cambia esa configuración.
Conservar un archivo en FAT32 no garantiza que aparezca en el menú sin una ruta
de arranque válida. A: es una partición FAT32 Basic de un SSD SATA, no un USB ni la
ESP del disco; por eso se ofrece una entrada explícita sin convertir la partición.

Tras guardar el trabajo y reiniciar manualmente, MSI indica F11 para escoger la
opción de arranque. La primera prueba termina intencionalmente en CPU detenida:
toma una foto y reinicia manualmente para volver al sistema habitual. Este programa
no escribe en el SSD después del salto ni ofrece apagado/reinicio propios.
[Referencia MSI del menú F11](https://us.msi.com/support/technical_details/MB_Boot_OS_Entry).

## Contrato del código propio y límites

El cuerpo no es un .efi: es el mismo hola.x86 de la v1 QEMU. Se ejecuta como código
x86-64 privilegiado y recibe RDI=contexto y R15=tabla propia: putchar +0, getchar +8,
puts ASCII +16. RBP apunta al contexto y debe conservarse, al igual que R15 y la pila
si el programa retorna. DF debe estar limpio. No se proporcionan los demás servicios
de la ROM anterior ni su tabla de asignación.

En esta primera entrega getchar devuelve Escape: **no hay teclado ni eco interactivo
tras ExitBootServices**. El monitor completo QEMU no se presenta como portado al PC.
No se instalan todavía GDT/IDT ni paginación propias: se conserva el estado heredado,
no se recicla memoria de firmware y las interrupciones enmascarables quedan desactivadas.
Los guardianes hardware de la ROM QEMU no se heredan automáticamente aquí.

Se acepta el GOP activo RGB/BGR directo de 32 bits, 640..4096 × 400..4096,
stride entre ancho y 8192 píxeles, y tamaño suficiente. PixelBitMask y BltOnly se
rechazan. El render 8×16 admite ASCII imprimible y CR/LF, con vuelta al inicio al
llenar la pantalla; no implementa scroll ni borrado. El mapa debe caber en 64 KiB.
El checksum FAGRAW64 detecta errores de los casos probados; no autentica programas.
Un payload privilegiado puede detenerse o cambiar memoria: no es un sandbox.

Antes del primer intento de salida, un error muestra su motivo y espera tecla
para liberar reservas y retornar. Después de intentar ExitBootServices, una salida
que no puede completarse solo dibuja el error y detiene la CPU: no vuelve a usar
consola/archivos UEFI. No se promete recuperar un fallo de hardware o del payload.

## Qué contiene un .efi y qué se extrajo

`inspeccionar-efi.py` comprueba las cabeceras y extrae sus secciones para análisis.
Se inspeccionaron los originales hola/eco y la entrada nueva. Sus informes están
en EVIDENCIAS/PUENTE_UEFI; las secciones binarias están en build/inspeccion-efi.

El PE32+ contiene cabeceras, punto de entrada, secciones, instrucciones, textos,
GUID y, en nuestro puente, la fuente. Extraer .text no elimina sus llamadas UEFI
ni convierte automáticamente la sección en un programa independiente. El paquete
METAL/INICIO.X86 sí declara el contrato propio que nuestro cargador valida.

## Fuentes

Se contrastaron las tablas y protocolos con [EDK II UefiSpec.h](https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Uefi/UefiSpec.h),
[GraphicsOutput.h](https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/GraphicsOutput.h)
y la [especificación UEFI](https://uefi.org/specs/UEFI/2.11/).
La fuente gráfica se conserva del proyecto QEMU, con crédito y dominio público
de Daniel Hepper / Marcel Sondaar / IBM en fuente.hex. No se usó ensamblador,
compilador ni linker para emitir las instrucciones del puente.
