# Servicios de memoria propios, ABI version 1

Este bloque implementa un servicio del firmware de 64 bits. No carga un OS,
no llama a UEFI y no necesita archivos .efi. Todos los bytes estan en .hex.

La entrada de 64 bits comprueba los guardianes y pasa por transition.hex a
F2000. Ejecuta las autopruebas, deja el cursor limpio y va al destino del
perfil: HLT normal en F22E0, RAM en F0600 o excepcion provocada en F1800.

## Contrato de allocate

Funcion en F2400, con pila valida y mapa de memoria del firmware instalado.

| Entrada o salida | Regla |
| --- | --- |
| RCX | Tamano solicitado en bytes, entero sin signo de 64 bits |
| CF=0 | Exito: RAX es comienzo del bloque y EDX=0 |
| CF=1 | Rechazo: RAX=0 y EDX indica el motivo |
| Alineacion | Se redondea hacia arriba a 16 bytes, comprobando overflow |
| Arena | [100000,180000), 512 KiB; extremos en hexadecimal |
| Estado | QWORD en RAM 9000, cursor de la siguiente asignacion |

EDX=1: tamano cero. EDX=2: overflow aritmetico. EDX=3: espacio insuficiente.
EDX=4: cursor fuera de limites o desalineado. Se modifica el cursor solo
despues de comprobar la peticion completa; rechazar no consume espacio.

La funcion destruye RAX,RDX,R8,R9 y banderas. Conserva RCX,RBX,RBP,R12-R15,
RSI y RDI. No pone a cero los bloques ni implementa free: es un asignador
lineal para la etapa de firmware, de una CPU y sin interrupciones externas.
El llamador debe comprobar CF antes de usar el puntero y respetar el tamano
del bloque. Los guardianes por pagina no sustituyen esos limites por objeto.

## Tabla propia en ROM F2600

Tabla de 48 bytes, little endian, con punteros de 64 bits:

| Offset | Contenido |
| --- | --- |
| 00 | Firma ASCII FAGMEM64, 8 bytes |
| 08 | Version: DWORD 1 |
| 0C | Tamano: DWORD 48 |
| 10 | Inicio de arena: QWORD 100000 |
| 18 | Fin exclusivo: QWORD 180000 |
| 20 | Direccion de allocate: QWORD F2400 |
| 28 | Direccion del estado: QWORD 9000 |

Esta tabla es nuestra interfaz, no una EFI System Table. Sus limites deben
mantenerse coherentes con allocate.hex, el mapa y las pruebas.

## Autopruebas reales ejecutadas por la CPU

Cada registro de cases.hex comprueba puntero devuelto, error, carry y cursor:

1. Pedir 1 byte: recibe 100000, cursor 100010.
2. Pedir 17 bytes: recibe 100010, cursor 100030; no se superpone al anterior.
3. Pedir cero: rechazo 1, cursor intacto.
4. Pedir FFFFFFFFFFFFFFFF: rechazo 2 por overflow, cursor intacto.
5. Pedir 512 KiB sin espacio suficiente: rechazo 3, cursor intacto.
6. Pedir todo el espacio restante: acepta hasta el limite exacto 180000.
7. Pedir 16 bytes con arena llena: rechazo 3, cursor intacto.
8. Desalinear el cursor a proposito y pedir 16: rechazo 4, estado intacto.

Al finalizar se restaura el cursor a 100000 y aparece:

```text
GREEN [Memory] bounded allocator OK
```

Una discrepancia imprime RED [Memory] allocator self-test FAIL y se detiene.
Todos los perfiles de 64 bits pasan por esta comprobacion, incluidos -Stress
y -Exception. El lanzador exige el mensaje exacto y el HLT del destino.

La arena comparte la region WorkRAM con el ensayo de RAM de 1 MiB. Primero
se ejecutan las autopruebas sin entregar bloques a programas externos;
despues se inicia el ensayo destructivo, si se selecciono -Stress. No deben
existir asignaciones vivas usadas por otro programa durante ese ensayo.

## Alcance actual y tamano

Es un servicio acotado de firmware, no un gestor general de memoria ni
prueba de ausencia de todos los errores de punteros. Falta mapa descubierto
dinamicamente y controladores de dispositivos. La arena y el estado tienen
reservas explicitas en guardians/layout.psd1.

Los bytes .hex siguen siendo la fuente de verdad. Compactar consiste en
escoger codificaciones mas cortas, aprovechar estados ya conocidos y evitar
trabajo repetido, conservando los contratos y pruebas. No se utilizara FASM
como ensamblador en esta etapa; la preferencia es mantener bytes manuales.
