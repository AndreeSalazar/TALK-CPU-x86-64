# Guardianes y semaforos

La idea es asignar a cada bloque un carril, un limite, un responsable y
una razon. Se comprueba al construir la ROM y tambien mediante permisos
que aplica la CPU virtual. No se utiliza Rust.

## Regla comun de colores

| Color | Significado | Accion |
| --- | --- | --- |
| RED / rojo | Violacion critica de una regla | Bloquear la construccion o detener el firmware con diagnostico |
| YELLOW / amarillo | Poco margen o cobertura pendiente | Avisar y conservar el motivo; permite continuar |
| GREEN / verde | Una comprobacion concreta ha pasado o una proteccion esta instalada | Continuar dentro del alcance comprobado |

El resumen adopta el color mas grave presente. Verde no demuestra que
todos los errores futuros sean imposibles. Una prueba negativa puede
aprobar en verde precisamente porque detecto el rojo que se provoco.

Cada hallazgo incluye un codigo estable (por ejemplo FG-CONTRACT), propietario,
motivo, correccion sugerida y, si corresponde, linea, offset y valores
esperado/encontrado. Rojo bloquea; no es solo una etiqueta de color.

## Guardianes del constructor

`layout.psd1` contiene las ventanas de ROM y reservas fisicas. Cada fuente
tiene Start, End y Why. Los rangos usan el extremo final excluido: [Start,End).
Por ejemplo, un byte en End ya pertenece al carril siguiente.

`check-layout.ps1` comprueba, antes de convertir los bytes:

- Cada archivo seleccionado tiene una ventana asignada.
- Las ventanas seleccionadas no se superponen. Las variantes alternativas
  pueden compartir una ventana solo cuando no se seleccionan juntas.
- Cada byte explicito cae dentro del carril de su archivo.
- Los offsets, el relleno y el tamano final son coherentes.
- Las reservas de memoria no se cruzan, caben en el mapa y estan alineadas.
- Las fuentes permanecen dentro de la carpeta del firmware.
- El esquema esta completo y conserva los recursos y contratos obligatorios.
- Los nombres de reservas son unicos y las alineaciones son potencias de dos.
- Las reservas criticas coinciden con las direcciones que usa el codigo raw.
- Los bytes de reset, activacion de NX/WP y entradas de ABI conservan sus contratos.

Si falla una regla, escribe un informe RED y lanza un error antes de generar
la nueva ROM. El lanzador no continua a QEMU. Si ya existia una ROM de una
construccion anterior, ese archivo no se utiliza como reemplazo silencioso.

Con 80 % o mas de un carril ocupado aparece YELLOW Margin. La entrada
de cada modo tiene un empalme de longitud fija: su contrato Fixed impide
crecer en el byte siguiente; no se avisa de margen para esos tres empalmes.
No elimina la comprobacion de limites ni los offsets exactos.

Actualmente, stress/fill.hex ocupa 59 de sus 64 bytes reservados (92,2 %):
por eso avisa en amarillo al construir -Stress. Los cinco bytes restantes
no pueden invadir clean.hex o corrupt.hex.

Cada construccion produce build/*-guardians.json, con resultado agregado,
hallazgos, propietario, razon y uso de cada ventana. El archivo *-map.json
conserva el conteo de bytes, fuentes y SHA256 de la ROM.

Un contrato de bytes evita que una edicion apague un guardian aunque siga
cabiendo en su carril. Los contratos se aplican a las fuentes del perfil
seleccionado; no sustituyen una verificacion de cada instruccion. Los puntos
criticos no pueden desaparecer silenciosamente de la politica: el comprobador
exige que sigan presentes. Cambiarlos requiere revisar el comprobador, mapa,
codigo y pruebas como un cambio deliberado del contrato de plataforma.

Ejemplo reproducible de una copia de prueba con el salto de reset alterado:

```text
RED [FG-CONTRACT] 16-bit\reset.hex:5: Contrato de bytes roto en ROM FFF0.
Motivo: La CPU debe saltar a nuestra entrada de reset.
Esperado: EA 00 00 00 F0; encontrado: EB 00 00 00 F0
Correccion: Revisar codigo, contrato y pruebas juntos; no actualizar el contrato solo para silenciarlo.
```

El ensayo altera solo una copia en build/guardian-fixture; las fuentes reales
no cambian. El resultado completo queda en build/guardian-example.json.

## Bandera persistente del servicio de memoria

El ABI v2 guarda cursor en 9000 y su complemento en 9008. Antes de asignar,
verifica rango, alineacion e integridad. Una peticion rechazada normalmente
por tamano cero, overflow o agotamiento no cambia el estado.

Si el cursor es invalido devuelve motivo 4; si no coincide su complemento,
devuelve motivo 6. Ambos escriben la causa en la bandera de 9010. Las llamadas
siguientes devuelven motivo 5 (servicio bloqueado), sin consumir memoria ni
borrar la causa original. Incluso una solicitud de cero respeta ese bloqueo.
Se requiere comprobar CF y EDX al llamar al servicio; el motivo persistido
permite explicar que detecto el guardian. No se continua asignando con
metadatos que ya fallaron una comprobacion.

El reinicio y las autopruebas usan un inicializador privado; no hay reset
publico en la tabla de servicios. Las autopruebas provocan corrupciones,
comprueban el bloqueo y restauran un estado valido antes del destino final.
El detalle del ABI esta en ../64-bit/services/README.md.

## Guardianes que ejecuta el hardware virtual

`32-bit/to-64.hex` construye cuatro niveles de paginacion y 512 entradas
de paginas de 4 KiB. CR0.WP impone los permisos de escritura incluso en
supervisor y EFER.NXE habilita el permiso de no ejecucion.

| Recurso | Regla en 64 bits | Motivo |
| --- | --- | --- |
| Pagina cero | No presente | Atrapar accesos a punteros nulos |
| ROM F0000-FFFFF | Lectura y ejecucion; escritura prohibida | Evitar modificar codigo y constantes |
| Paginas de datos | Lectura y escritura; ejecucion prohibida (NX) | Evitar ejecutar buffers, pilas o tablas como instrucciones |
| Guarda de pila normal 8E000-8EFFF | No presente | Detectar el cruce inferior desde 8F000 |
| Guarda DF 86000-86FFF | No presente | Detectar cruce inferior de IST1 |
| Guarda NMI 84000-84FFF | No presente | Detectar cruce inferior de IST2 |
| Guarda MC 82000-82FFF | No presente | Detectar cruce inferior de IST3 |
| Direcciones desde 200000 | No presentes en este perfil | Evitar usar memoria fuera del mapa actual |

Todas las direcciones de estas tablas estan en hexadecimal. Las pilas
utiles ocupan una pagina inmediatamente por encima de su guarda y crecen
hacia abajo. Los topes siguen siendo 90000, 88000, 86000 y 84000.

Al ejecutar la entrada larga aparece GREEN [CPU] guardians active. Significa
que se alcanzo ese punto con los permisos instalados. Una violacion da un
page fault, que el handler informa con RED [CPU], RIP, error y CR2.
Un fallo detectado por la prueba de RAM aparece con RED [RAM].

## Pruebas de los limites

Desde la raiz:

```powershell
.\test-firmware.ps1
```

Ejecuta diecinueve pruebas de reglas del constructor y catorce pruebas reales en
QEMU. Para ver solo las reglas estructurales: `.\test-guardians.ps1`.
Las pruebas estructurales alteran copias de metadatos y una copia aislada
de los bytes de reset: no editan tus fuentes reales ni una ROM existente.
Ademas se ejecutan once autopruebas del servicio en cada perfil de 64 bits.

Para observar las violaciones hardware individualmente:

```powershell
.\run-firmware.ps1 -Exception write -Check
.\run-firmware.ps1 -Exception execute -Check
.\run-firmware.ps1 -Exception guard -Check
.\run-firmware.ps1 -Exception stack -Check
```

Se comprueba que escribir en ROM da error de pagina 3, ejecutar datos da
error 11, y escribir en la guarda da error 2. Son codigos hexadecimales.
La ultima prueba coloca la pila al borde y provoca una excepcion: entregar
su marco cruza la guarda, causa fallos de pagina anidados y llega al doble
fallo sobre IST1, con marco 87FC8 y CR2=8EFF8. No se continua tras el fallo.

Los informes son build/guardian-test-results.json y build/test-results.json.
Los mensajes RED de estos casos son intencionales; deben ser detectados.

## Alcance y avisos amarillos

El aviso Coverage permanece amarillo porque los guardianes hardware empiezan
al activar paginacion al final de la etapa de 32 bits. Todavia falta
diagnostico propio en las fases tempranas y en el intervalo antes de LIDT.

Esto comprueba fronteras de archivos, reservas y permisos por pagina.
No verifica el significado de cada instruccion ni impide un indice incorrecto
entre dos objetos que comparten una pagina escribible. Tampoco impide que
codigo privilegiado cambie deliberadamente sus propias tablas o permisos.
Una pila que salte por encima de toda la guarda puede escapar de ese control.
Los limites se aplican al perfil QEMU actual, no a cualquier placa fisica.
El complemento de cursor detecta corrupciones individuales, no cambios
coherentes en ambos campos ni errores de un componente privilegiado que
modifique deliberadamente el propio guardian.

El mapa declara contratos; no recompila automaticamente los operandos de
las instrucciones. Cambiar una direccion exige actualizar sus referencias
en los .hex y las pruebas correspondientes. Los perfiles de semaforo no
sustituyen esa revision.

Referencia: [AMD64 Architecture Programmer's Manual, volumen 2](https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/24593.pdf),
paginacion, NX, CR0.WP y excepciones de pagina.

## Plataforma de destino

El constructor admite `-Platform QEMU` por defecto y lo registra en el mapa.
Pedir `-Platform MS-7C52` bloquea antes de crear archivos con `RED [FG-PLATFORM]`:
no están implementados el inicio Ryzen/DDR4 ni los controladores físicos.
Cambiar ese parámetro no convierte las fuentes QEMU en un port de la placa.
Véase [el plan físico](../../EVIDENCIAS/PC_REAL/PLAN-METAL.md).
