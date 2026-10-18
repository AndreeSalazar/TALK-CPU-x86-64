# Servicios de memoria propios, ABI version 2

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
| Estado | Reserva de 32 bytes en RAM 9000: cursor, complemento y bandera |

EDX=1: tamano cero. EDX=2: overflow aritmetico. EDX=3: espacio insuficiente.
EDX=4: cursor fuera de limites o desalineado. EDX=6: el cursor y su
complemento no coinciden. Ambos son fallos criticos: escriben su motivo
en la bandera persistente y rechazan sin cambiar cursor ni complemento.
EDX=5 indica que ya habia un bloqueo y conserva el motivo original.
Incluso pedir cero devuelve 5 si esta bloqueado.

Los errores normales 1, 2 y 3 no cambian el estado ni consumen espacio.
La ruta aceptada actualiza cursor y complemento despues de validar todo.
La implementacion es de una sola CPU, sin asignaciones concurrentes.

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
| 08 | Version: DWORD 2 |
| 0C | Tamano: DWORD 48 |
| 10 | Inicio de arena: QWORD 100000 |
| 18 | Fin exclusivo: QWORD 180000 |
| 20 | Direccion de allocate: QWORD F2400 |
| 28 | Direccion del estado: QWORD 9000 |

Esta tabla es nuestra interfaz, no una EFI System Table. Sus limites deben
mantenerse coherentes con allocate.hex, el mapa y las pruebas.

Estado relativo a RAM 9000: cursor en +00, su complemento bit a bit en +08,
causa del bloqueo en +10. Son tres QWORDs; los ocho bytes de +18 estan
reservados y no se usan. El complemento detecta corrupciones individuales;
no es una firma criptografica ni detecta dos campos alterados de forma coherente.
El inicializador privado se usa al arrancar y despues de las autopruebas.
No existe una funcion publica de desbloqueo en esta tabla de servicio.

## Autopruebas reales ejecutadas por la CPU

Cada registro de cases.hex comprueba puntero devuelto, error, carry y cursor:

1. Pedir 1 byte: recibe 100000, cursor 100010.
2. Pedir 17 bytes: recibe 100010, cursor 100030; no se superpone al anterior.
3. Pedir cero: rechazo 1, cursor intacto.
4. Pedir FFFFFFFFFFFFFFFF: rechazo 2 por overflow, cursor intacto.
5. Pedir 512 KiB sin espacio suficiente: rechazo 3, cursor intacto.
6. Pedir todo el espacio restante: acepta hasta el limite exacto 180000.
7. Pedir 16 bytes con arena llena: rechazo 3, cursor intacto.
8. Desalinear el cursor a proposito y pedir 16: rechazo 4, cursor intacto y
   bloqueo con motivo 4.
9. Volver a pedir 16: rechazo 5, cursor y motivo original intactos.
10. Reinicializar para una nueva prueba y corromper solo el complemento:
    rechazo 6, cursor intacto y bloqueo con motivo 6.
11. Pedir cero con ese bloqueo: rechazo 5, motivo 6 conservado.

Al finalizar se restaura el cursor a 100000 y aparece:

```text
GREEN [Memory] bounded allocator OK
```

Una discrepancia imprime RED [Memory] allocator self-test FAIL y se detiene.
Antes de ese resultado se exige GREEN [Memory] integrity latch OK: confirma
que las corrupciones intencionales fueron detectadas y el bloqueo persistio.
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
