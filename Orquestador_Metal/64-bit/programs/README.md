# Hola mundo y eco con bytes propios

`./tools/qemu/run-firmware.ps1 -Monitor` desde la raiz construye la ROM y exporta
`build/hola.x86` y `build/eco.x86`. Pulsa `o` o `e`; Escape sale del eco.
Los archivos UEFI originales de `src/` permanecen intactos.

`hola.hex` contiene solo 12 bytes de instrucciones y 28 de texto. Sus primeros
bytes son `48 8D 35 05 00 00 00`: obtener la direccion relativa del texto. Luego
`41 FF 57 10` llama a nuestra salida y `C3` retorna. No hay cabecera PE ni `.efi`.
Se elimino el hueco previo entre instrucciones y texto: el programa tiene 40 bytes.
La cabecera propia agrega 24: el paquete exportado mide 64 bytes.

`eco.hex` lee y devuelve ASCII imprimible caracter por caracter. CR, LF o CRLF
generan una sola linea nueva. BS y DEL emiten borrado visual; no mantienen un
buffer de edicion ni impiden borrar mas alla del inicio de linea. Escape retorna.
No hay limite artificial de texto almacenado porque no se guarda la linea.

## Paquete FAGRAW64 v1

| Offset | Bytes | Campo |
|---|---:|---|
| 0 | 8 | ASCII `FAGRAW64` |
| 8 | 4 | Longitud del cuerpo: 1..4072 |
| 12 | 4 | Entrada relativa al cuerpo, menor que su longitud |
| 16 | 4 | Suma de los bytes del cuerpo, modulo 2^32 |
| 20 | 4 | Flags reservados: cero |
| 24 | variable | Instrucciones y datos |

Los enteros usan little endian. Los `*-header.hex` contienen los campos
escritos explicitamente; al cambiar el cuerpo hay que revisar tamano y suma.
Los `@` de las fuentes indican posiciones dentro de la ROM, no direcciones
absolutas que deba usar el programa. Las referencias RIP relativas permiten copiarlo.
El constructor exporta los bytes de cada paquete sin generar instrucciones.

## Contrato de ejecucion

El monitor selecciona dos ventanas fijas de ROM, F4000 o F5000. El cargador
valida la cabecera antes de leer el cuerpo, limita cada paquete a su ventana
de 4096 bytes y comprueba la suma. No se ofrece un puntero de origen arbitrario.
En caso de rechazo imprime `RED [load]` y el campo responsable, y retorna.

El cuerpo se copia a RAM 80000..80FFF, que se borra antes de cada carga.
Durante la copia es RW/NX; durante la ejecucion es RX. Al retornar restaura
NX antes de habilitar escritura e invalida la traduccion en cada transicion.
La entrada es `80000 + offset`; el programa debe retornar con RET.

R15 apunta a una tabla de tres servicios propios:

| Posicion | Servicio |
|---:|---|
| 0 | putc: AL contiene el caracter; conserva RAX, RCX y RDX |
| 8 | getc: devuelve AL; modifica RDX |
| 16 | puts: RSI apunta a texto terminado en cero; modifica RAX y RSI |

El programa conserva RBX, RBP, R12..R15 y el equilibrio de la pila. Corre en
long mode con IF=0 y devuelve DF=0. El cargador tambien limpia DF al regresar.
La pagina es de solo lectura durante la ejecucion: estos dos ejemplos usan
registros y la pila para su estado. Un programa que necesite datos mutables
necesitara un contrato adicional; no debe escribir sobre su propio codigo.

Estos son programas propios privilegiados, sin aislamiento frente a codigo
que deliberadamente cambie las tablas del firmware. La suma verifica integridad
basica; no es autenticacion. La extension `.x86` es una convencion del proyecto.
Los ejemplos `o` y `e` están incluidos en la ROM. La orden `d` carga un paquete
externo desde FAT32 con el lector de [storage](../storage/README.md). Antes de
llamar a este cargador, exige la longitud completa del archivo y verifica sus
cadenas. No se reciben paquetes por UART.

## Comprobacion

`./tools/tests/test-firmware.ps1` incluye el recorrido normal: hola, eco, borrado, Enter,
Escape y hola otra vez. La traza confirma ejecucion en RAM. La entrada de la
prueba de eco se envia caracter a caracter para respetar el FIFO del UART.

`./tools/tests/test-programs.ps1` modifica copias de la ROM y comprueba ocho rechazos:
firma, longitud cero, exceso de ventana, longitud maxima uint32, entrada igual
al extremo, flags, checksum y cuerpo alterado. Cada caso verifica que el monitor
siga operativo y que el cuerpo no llegue a ejecutarse.
