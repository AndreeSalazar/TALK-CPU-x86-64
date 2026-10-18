# Compactacion manual del firmware

Preferencia del proyecto: mantener los .hex como fuente de verdad.
La CPU ejecuta los bytes directamente. No se sustituiran por fuentes FASM
ni se anadira un ensamblador para esta fase.

El criterio inspirado en programacion ensamblador compacta es elegir
codificaciones cortas, reutilizar estados conocidos y eliminar repeticiones,
conservando interfaces, guardianes y pruebas. Menos bytes no implica
automaticamente menos ciclos: no se presenta esta medicion como un benchmark.

## Primera reduccion comprobada

Referencia anterior: commit 7430a47, servicio de memoria de 64 bits probado.
Perfil medido: ROM normal faggin-64, sin -Stress ni -Exception.
Estas cifras corresponden a la compactacion del commit 1464ec2. El ABI v2
agrega controles de integridad despues de esa medicion; su tamano actual
se registra en build/faggin-64-map.json y no se confunde con este ahorro historico.

| Bloque | Antes | Despues | Ahorro |
| --- | ---: | ---: | ---: |
| diagnostics/init.hex | 211 | 182 | 29 bytes |
| services/allocate.hex | 142 | 100 | 42 bytes |
| Total explicito del perfil normal | 2319 | 2248 | 71 bytes, 3,06 % |
| Imagen ROM con relleno | 65536 | 65536 | 0 bytes |

El total explicito incluye instrucciones, constantes, mensajes y autopruebas.
La ROM sigue teniendo 64 KiB porque conserva su mapa y el vector de reset
en el extremo. El relleno no es una instruccion ejecutada por cada byte.
Las variantes Stress y Exception contienen fuentes adicionales y tienen
sus propios informes de tamano; no se les atribuye el total del perfil normal.

## Que cambio y por que conserva el comportamiento

En init.hex, REP STOSD deja RDI=7068. Los campos de TSS se escriben usando
esa base y desplazamientos de 8 bits, en vez de repetir direcciones absolutas.
REP y LOOP terminan con RCX=0; cargar CL o CH permite preparar los siguientes
contadores con menos bytes. Esas dependencias quedan comentadas junto al codigo.

En allocate.hex se agruparon los rechazos junto al cuerpo. Todas las ramas
condicionales alcanzan sus destinos mediante desplazamientos de 8 bits.
EDX se limpia al entrar, asi que los rechazos pueden establecer solo DL.
La ruta aceptada sigue teniendo una sola escritura al cursor, despues de
todas las comprobaciones. La interfaz RCX/RAX/EDX/CF no cambio.

No se eliminaron reglas, autopruebas ni manejo de excepciones para lograr
este ahorro. En esa comparacion la tabla seguia apuntando a F2400 y mantenia
version 1. La version 2 posterior amplia el contrato con un bloqueo persistente.

## Verificacion y criterio para continuar

En esa comparacion se ejecuto `.\test-firmware.ps1`: catorce perfiles QEMU,
ocho pruebas estructurales y las ocho autopruebas del asignador de entonces,
en cada perfil de 64 bits. Se exige el texto exacto, estado esperado de CPU,
destinos de HLT y diagnosticos correctos para las excepciones provocadas.

Los informes build/*-map.json registran bytes explicitos y SHA256.
Los resultados quedan en build/test-results.json y guardian-test-results.json.
La bateria actual conserva los catorce perfiles y amplia a diecinueve las
reglas estructurales y a once las autopruebas del servicio de memoria.
No se agregan esos productos al repositorio; se pueden regenerar.

Las proximas reducciones deben mantener cada contrato y pasar la misma
bateria. Antes de cambiar una direccion, tambien deben actualizarse sus
referencias en el codigo y guardianes. Las zonas con dependencias de estado
exigen revisar los registros que REP, LOOP y las funciones dejan al salir.

Este registro describe la primera compactacion, no afirma que ya se alcanzo
el menor tamano posible ni que todas las funciones de un firmware esten completas.
