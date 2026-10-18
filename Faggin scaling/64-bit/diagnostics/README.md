# Diagnostico de excepciones en 64 bits

Este bloque permite que el firmware informe un fallo de CPU y se detenga
en una direccion conocida. No intenta continuar una instruccion fallida.
Todo el codigo ejecutado por la CPU sigue escrito en bytes .hex.

## Arranque y responsabilidades

La transicion de 32 bits salta ahora a F1000, con CS=18 y paginacion activa.
`init.hex` prepara el diagnostico y entrega el control a F0400, la entrada
larga anterior. Por tanto, la comprobacion con R8 y el mensaje de 64 bits
se ejecutan despues de instalar la IDT y cargar el registro de tarea.

Orden de preparacion:

1. Fijar RSP=90000 y poner a cero la TSS de 104 bytes.
2. Preparar RSP0 y las pilas IST para doble fallo, NMI y machine check.
3. Copiar la GDT desde ROM a RAM 6000 y recargar GDTR. LTR puede escribir
   el bit busy del descriptor TSS: la tabla debe estar en RAM escribible.
4. Cargar TR con el selector TSS 20.
5. Construir 256 puertas de interrupcion en RAM 8000, cada una de 16 bytes.
6. Asignar stubs propios a los vectores 00-1F y las pilas IST a 8, 2 y 18.
7. Cargar IDTR y continuar hacia la entrada larga normal.

Los selectores y direcciones de este documento estan en hexadecimal.
Las interrupciones enmascarables siguen desactivadas; no hay un controlador
de interrupciones inicializado para usar dispositivos externos.

## Archivos

- `init.hex`: GDT en RAM, TSS, IDT y entrega a la entrada normal.
- `stubs.hex`: entradas separadas para 32 excepciones y una entrada generica
  para los demas vectores. Esa entrada generica informa vector FF.
- `handler.hex`: captura vector, error, RIP, CR2 y direccion del marco.
- `output.hex`: imprime texto y valores hexadecimales de 16 digitos.
- `messages.hex`: etiquetas y nombres para cinco causas frecuentes.
- `pointers.hex`: punteros GDTR e IDTR de 10 bytes usados en modo largo.
- `tests/`: instrucciones que provocan fallos reales dentro de QEMU.

Los stubs normalizan la pila a vector,error,RIP,CS,RFLAGS,... antes de
entrar al handler. Para excepciones que traen un error hardware se conserva
ese valor; en las otras se coloca un cero sintetico. No se debe usar INT n
para simular una excepcion que normalmente trae error hardware: INT no
construye ese mismo marco. Las pruebas emplean las instrucciones causantes.

## Leer un diagnostico

Ejemplo de la prueba de pagina:

```text
RED [CPU] Faggin scaling: CPU fault vector=000000000000000E
rip=00000000000F1805
error=0000000000000000
cr2=0000000000200000
frame=000000000008FFC8
cause=page fault (#PF)
```

| Campo | Significado |
| --- | --- |
| vector | Numero de excepcion; 0E corresponde a page fault |
| rip | Direccion de la instruccion guardada por la CPU; para estas pruebas, la causante |
| error | Codigo hardware, o cero sintetico cuando la excepcion no trae codigo |
| cr2 | Direccion asociada al ultimo page fault; no indica la causa de otros vectores |
| frame | Direccion de la pila con el marco normalizado |
| cause | Nombre de la clase de fallo, no una explicacion automatica de todo el error de programacion |

En este caso, MOV RAX,[RAX] intenta leer 200000, fuera de nuestro mapa.
El error de pagina cero indica una lectura de supervisor a una pagina
no presente. El valor CR2 identifica esa direccion; no es el RIP.

## Pruebas

Desde la raiz del proyecto:

```powershell
.\run-firmware.ps1 -Exception divide -Check
.\run-firmware.ps1 -Exception invalid -Check
.\run-firmware.ps1 -Exception page -Check
.\run-firmware.ps1 -Exception general -Check
.\run-firmware.ps1 -Exception double -Check
```

| Caso | Accion del firmware | Resultado exigido |
| --- | --- | --- |
| divide | DIV con divisor cero | Vector 00, RIP F1809, error 0 |
| invalid | UD2 | Vector 06, RIP F1800, error 0 |
| page | Lectura de 200000 sin mapear | Vector 0E, RIP F1805, error 0, CR2=200000 |
| general | Cargar DS con selector 30 fuera de la GDT | Vector 0D, RIP F1804, error 30 |
| double | Marcar no presentes las puertas UD y NP, y ejecutar UD2 | Vector 08, RIP F1810, error 0, marco en IST1 |

El doble fallo es una cadena real de excepciones, no un mensaje simulado.
La prueba exige frame=87FC8; las cuatro primeras exigen frame=8FFC8.
Esto comprueba que se utilizo una pila distinta para el doble fallo.
No prueba todos los posibles fallos de la pila normal.

El lanzador compara todos los campos y el texto, y exige alcanzar el HLT
del handler en F1597. Un mensaje parcial o un triple fallo no aprueban.
Los casos provocados no se combinan con -Stress. Sin -Check se puede
observar el diagnostico directamente y salir con Ctrl+C.

La bateria completa se ejecuta con `.\test-firmware.ps1`: catorce casos
en QEMU y ocho reglas del constructor. Incluye los cinco casos anteriores
y cuatro violaciones de guardianes: escritura en ROM, ejecucion de datos,
acceso a guarda y cruce real de pila. Ver `../../guardians/README.md`.
El informe queda en build/test-results.json y las reglas del constructor
en build/guardian-test-results.json.

## Memoria reservada

| Recurso | Region o tope de pila |
| --- | --- |
| GDT en RAM | 6000-602F |
| TSS | 7000-7067 |
| IDT | 8000-8FFF |
| Pila normal | Tope 90000, crece hacia abajo |
| IST1: doble fallo | Tope 88000, crece hacia abajo |
| IST2: NMI | Tope 86000, crece hacia abajo |
| IST3: machine check | Tope 84000, crece hacia abajo |

Cada pila util de 4 KiB tiene una pagina de guarda no presente debajo:
8E000 para la normal, 86000 para DF, 84000 para NMI y 82000 para MC.
Un cruce que accede a esa guarda produce un fallo de pagina. No detecta
un salto que omita toda la pagina de guarda. Ninguna region se cruza con
la prueba de RAM, que usa 100000-1FFFFF.

## Limites de cobertura

La IDT tiene entradas para todos los vectores; se provocan cinco clases de
excepcion mediante nueve casos, incluidos los limites de memoria. NMI y
machine check tienen IST propia;
no se simulan fallos fisicos de hardware ni se certifica su recuperacion.
Los vectores sin nombre especifico se informan numericamente con causa
generica. El manejador es terminal y no restaura registros para volver.

La fase de 16 bits, la de 32 y el intervalo anterior a LIDT en init.hex
todavia no tienen diagnostico propio de excepciones. Un triple fallo no
puede ser capturado por este handler. Nada de esto sustituye la
inicializacion especifica de una placa fisica ni la validacion de toda UEFI.

Referencia: [AMD64 Architecture Programmer's Manual, volumen 2](https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/24593.pdf),
secciones de excepciones, IDT, TSS de 64 bits e Interrupt Stack Table.
