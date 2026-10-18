# Arranque propio desde RESET

Decisión del proyecto: conservar el firmware propio, sin una entrada `.efi`.
Esta carpeta documenta el contrato para el siguiente desarrollo. No contiene
todavía un controlador de disco ni un mecanismo de búsqueda de programas.

## Dos responsabilidades distintas

**Iniciar el firmware.** La CPU comienza con el código accesible desde su vector
de RESET. En QEMU, el lanzador instala nuestra imagen mediante `-bios`. En una
placa física se necesita una imagen adaptada a esa plataforma y su mecanismo
de almacenamiento de firmware. Una carpeta del disco no sustituye ese mecanismo.
La ROM de QEMU no está preparada para grabarse en la placa MSI.

**Buscar un programa.** Una vez que Orquestador del Metal controla la máquina,
puede inicializar almacenamiento, reconocer un formato propio, escoger un
programa, validarlo y ejecutarlo. Esa búsqueda todavía no está implementada;
actualmente `o` y `e` seleccionan paquetes incluidos en la ROM.

Cambiar la extensión de un archivo, el nombre de la carpeta o una etiqueta del
disco no hace que el firmware de fábrica comprenda el formato FAGRAW64.
Tampoco Windows instala ese firmware por encontrar una carpeta con este nombre.

## Inspiración en UEFI

Se adoptará la separación de responsabilidades: descubrimiento de medios,
política de selección, validación de la imagen y entrega del control. El formato
de programa sigue siendo FAGRAW64 y sus instrucciones siguen en `.hex`.

Como referencia, UEFI define una ruta x64 de medios extraíbles:
`EFI\BOOT\BOOTX64.EFI`. Esa convención pertenece a su gestor de arranque; no
se implementa ni se sustituye por renombrar nuestro archivo `.x86`.
[Especificación UEFI, gestor de arranque](https://uefi.org/specs/UEFI/2.11/03_Boot_Manager.html#removable-media-boot-behavior).

## Próxima entrega comprobable en QEMU

1. Elegir un único dispositivo de almacenamiento emulado y escribir su
   controlador con tiempos de espera acotados. Declarar el soporte exacto.
2. Definir dónde se encuentra el catálogo propio y cómo expresa posiciones,
   longitudes y orden de selección, sin depender de nombres que nadie interpreta.
3. Leer y validar un paquete FAGRAW64 externo antes de transferir el control.
   La longitud realmente leída debe coincidir con la anunciada.
4. Probar medio ausente, lectura fallida, catálogo inválido, transferencia
   truncada, límites e integridad; cada rechazo debe explicar el motivo y
   conservar el monitor operativo.

El transporte externo no cambia el privilegio de los programas actuales. La
suma de bytes comprueba integridad básica; no aporta autenticación. El salto
a hardware físico será otra entrega, con inicialización y recuperación propias
de esa placa. No se modifica el disco personal ni el firmware instalado aquí.
