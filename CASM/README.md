# CASM: significado, guardianes y bytes visibles

Diseño inicial propuesto para Orquestador del Metal. CASM combina una sintaxis
cercana a C con control explícito de la generación x86-64. Su compilador se
plantea escrito en C. No es C completo ni existe todavía un compilador CASM en
este repositorio. El puente EFI y el ejemplo manual .hex sí funcionan.

La inspiración en Rust es comprobar contratos y rechazar operaciones inválidas
antes de ejecutar. No se ha implementado un sistema de préstamos ni se afirman
las garantías de seguridad de memoria de Rust.

## Así se vería

El [ejemplo propuesto](ejemplos/hola.casm) describe el mismo saludo que ya existe
en el programa manual:

```text
target x86_64;
abi metal64;

program hola {
    const saludo: ascii_z = "Hola mundo desde mi .hex!\r\n";
    puts(saludo);
    return;
}
```

`ascii_z` significa una cadena ASCII inmutable con terminador cero. `puts` es
una operación conocida del contrato metal64, no una llamada a libc. En este
primer diseño no se aceptan punteros arbitrarios, escrituras de memoria,
ensamblador incrustado ni saltos aportados por el usuario. Una ampliación deberá
definir sus reglas y comprobaciones antes de admitirla.

```text
Fuente CASM
  → análisis de sintaxis, nombres, tipos y operaciones admitidas
  → guardianes semánticos y operaciones validadas
  → backend x86-64 escrito en C
  → .hex + mapa fuente/instrucción/offset
  → verificador de emisión
  → bytes del paquete FAGRAW64 (.x86)
  → cargador existente → CPU
```

Para este ejemplo, el cuerpo manual de referencia ya es:

| Offset del cuerpo | Bytes HEX | Instrucción / significado |
|---|---|---|
| 0x00 | 48 8D 35 05 00 00 00 | LEA RSI,[RIP+5]: dirección del texto en 0x0C |
| 0x07 | 41 FF 57 10 | CALL [R15+16]: servicio puts propio |
| 0x0B | C3 | RET: volver al cargador |
| 0x0C | 48 6F 6C 61 ... 0D 0A 00 | Texto ASCII, CR/LF y terminador cero |

La referencia completa está en
[hola.hex](../Orquestador_Metal/64-bit/programs/hola.hex). Sus direcciones @4018
y @4024 pertenecen al montaje anterior; los offsets de esta tabla son relativos
al cuerpo. La tabla no contiene un nuevo binario compilado desde CASM.

## Dos controles con responsabilidades distintas

| Control | Qué debería comprobar | Ejemplo de rechazo |
|---|---|---|
| CASM: significado | Tipos, nombres, capacidad de llamar al servicio y operaciones permitidas | Pasar un número a puts o usar una operación desconocida |
| Emisión HEX: estructura | Codificaciones admitidas, offsets, destinos, regiones de código/datos, límites y ABI | Desplazamiento fuera de rango, salto a datos o instrucción no autorizada |

HEX hace visibles los bytes; **verlos no los valida automáticamente**. El segundo
control debe ser una herramienta real, con reglas y comprobaciones independientes
del emisor donde sea posible. Un listado o un checksum por sí solos no prueban que
el programa corresponda al significado del fuente. Revisar la secuencia de una
plantilla admitida y contrastarla con su operación aporta un control más fuerte.

Si se edita el .hex después de compilar, se invalida la correspondencia registrada
con el fuente y debe volver a verificarse. El cargador actual comprueba el formato
FAGRAW64 y su suma; no interpreta CASM ni impone todavía estas reglas semánticas.

## Semáforo propuesto

- **Rojo:** impide emitir el paquete ejecutable y explica regla, línea y motivo.
  Ejemplo: `CASM-TIPO: puts requiere ascii_z; se recibió u64`.
- **Amarillo:** condición permitida que merece revisión. Ejemplo: poca capacidad
  disponible antes del límite de cuerpo de 4072 bytes del puente.
- **Verde:** una comprobación identificada pasó; no declara seguro todo el programa.
  Ejemplo: `HEX-DESTINO: texto completo dentro de la región de datos`.

El emisor deberá preservar RBP, R15 y la pila al retornar, usar la tabla propia y
limitarse al contrato del [puente](../Puente_Metal/LEEME.md). Un salto incorrecto o
un error del compilador puede seguir causando corrupción o detención en ring 0.

## Primer alcance para implementar

1. Aceptar únicamente target/abi, un programa, constantes ascii_z, puts y return.
2. Analizar el programa completo antes de publicar un paquete ejecutable.
3. Emitir instrucciones relativas a RIP, datos y cabecera FAGRAW64 con informe
   que relacione fuente, operación, bytes y offsets.
4. Verificar la emisión y probar el saludo y los rechazos en QEMU antes de copiar
   un paquete CASM al SSD real.

Esto es un compilador pequeño especializado con salida inspeccionable. El nombre
«Compilador Sintético Directo al Metal» expresa la intención del proyecto; no
demuestra por sí mismo innovación, corrección, optimización o seguridad.
