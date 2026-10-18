# CASM 0.1 — C-shaped source, guarded x86-64 emission

The first CASM compiler is implemented in C. It accepts the bounded grammar in
[LANGUAGE.md](LANGUAGE.md), emits inspectable HEX and compiler IR, and uses a
separate Python verifier to publish a FAGRAW64 executable packet.

**This is not a complete C implementation.** C11, documented by the public
[WG14 N1570 draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf),
is the reference for evaluating future language features. The
[C coverage table](LANGUAGE.md#c-coverage-and-policy) distinguishes implemented
behavior, restrictions and future work. Unsupported source is rejected.

Rust inspires explicit contracts and rejection before execution. CASM does not
implement Rust, borrow checking, ownership analysis or a memory-safety proof.
The earlier `program` / `ascii_z` sketch is superseded by this C-shaped grammar.

## Working source

```c
void metal_main(void) {
    const char greeting[] = "Hola mundo desde mi .hex!\r\n";
    metal_puts(greeting);
    return;
}
```

`metal_puts` is a built-in Metal service, not libc `puts`. Its output does not
append a newline automatically. Keywords, API names and diagnostics are English;
the greeting preserves the existing hand-written program for byte comparison.

```powershell
.\CASM\compile.ps1
.\CASM\compile.ps1 -Source .\CASM\examples\hello.casm
.\CASM\test.ps1
.\CASM\test.ps1 -Qemu
```

The scripts use installed Clang and Python. Override `-Compiler` / `-Python` as
needed. Clang/LLVM compiles our C implementation into a Windows tool: this is the
**bootstrap dependency**. That tool uses our own encoder for target instructions;
it does not invoke LLVM, an assembler or a linker to generate the target payload.

Compilation creates a unique directory under `build/CASM/run-*` containing:

| File | Purpose |
|---|---|
| source.casm | Frozen source snapshot shared by both controls |
| program.ir.json | Constants, calls, return, source lines and body offsets |
| program.hex | Body bytes as readable hex, without the packet header |
| INICIO.X86 | Packet published only after verification succeeds |
| verified.json | Source/artifact SHA-256, byte mapping and verification scope |

No physical disk, boot entry or installed payload is changed. Failed runs have
a different directory and do not publish a new executable. When calling the
low-level host tool directly, use distinct fresh output paths; the PowerShell
wrapper supplies that discipline.

## Two controls

```text
C-shaped CASM source
  → C frontend: syntax, symbols, immutable-string rules
  → bounded IR
  → own x86-64 encoder: HEX + source/offset metadata
  → separate verifier: reconstruct allowed instruction/data layout
  → FAGRAW64 packet
  → existing EFI bridge → ExitBootServices → CPU
```

The frontend rejects undefined/duplicate names, wrong initializer types,
unsupported operations, statements after return and source limits. The verifier
independently reconstructs the entire allowed body from IR: RIP-relative LEA,
`CALL [R15+16]`, RET and terminated ASCII data. It rejects altered opcodes,
displacements, region sizes, targets, offsets and ABI metadata.

**The C frontend remains trusted for source semantics.** The verifier does not
parse the source again or prove source-to-IR equivalence. Hashes bind the report
to the exact files; they are not semantic proof or authentication. Coordinated
changes to IR and HEX can describe a different valid program. This structural
second control is not a sandbox or a certified compiler.

RED blocks compilation/packaging with a rule and reason. YELLOW identifies an
unused constant or a body approaching 4072 bytes. GREEN names the check passed,
without declaring all future execution safe.

## Layout and target contract

| Component | Responsibility |
|---|---|
| src/casm.h | Bounded intermediate representation and limits |
| src/frontend.c | Lexer, parser, symbols and source guardians |
| src/emitter.c | Byte encoder and unverified IR/HEX emission |
| src/main.c | Host files and command-line entry |
| verify.py | Separate emission verifier and packet publisher |
| examples/ | Accepted source example |
| build.ps1 / compile.ps1 | Bootstrap; freeze, compile and verify one program |
| test.py / test.ps1 | Source/output rejection tests and optional QEMU integration |

The target is x86-64 / metal64, body entry 0. It preserves RBP, R15 and the return
stack, relies on the bridge's `puts` at `[R15+16]`, and uses RIP-relative data.
This calling convention is not the Windows or System V C ABI. The existing
[bridge contract](../Puente_Metal/LEEME.md) still applies.

The generated hello packet is 64 bytes, identical to the hand-written packet.
[Evidence](../EVIDENCIAS/CASM/LEEME.md) records 39 host cases and actual QEMU/OVMF
execution with framebuffer verification. Previous physical photographs show the
manual program; they are not a new physical execution of compiler output.
