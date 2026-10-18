# Puente instalado en A: BMO

El 18 de octubre de 2026 se instalaron los dos archivos del puente comprobado en
QEMU/OVMF. El usuario eligió expresamente A: BMO con una entrada separada.

- `A:\EFI\ORQUESTADOR\METAL.EFI`: entrada UEFI, SHA-256 verificado.
- `A:\METAL\INICIO.X86`: programa propio, SHA-256 verificado.
- Entrada: **Orquestador del Metal (prueba)**.
- Identificador: `{57cb1745-7f84-11f1-930d-c3a2d7ca848a}`.

La partición FAT32 sigue siendo la partición 2 del disco 0, de tipo BasicData.
No se formateó, no se cambió GPT, no había archivos anteriores en esas dos rutas.
La nueva entrada quedó al final; las cuatro entradas anteriores conservaron su
orden. No se pobló `A:\EFI\BOOT\BOOTX64.EFI`, ruta de la entrada antigua BMO-X.
La entrada y sus rutas se verificaron nuevamente por lectura tras la instalación.

Los registros [de archivos](instalacion.json), [de entrada](entrada.json) y del
firmware [antes](firmware-antes.txt) / [después](firmware-despues.txt) documentan
la instalación. **No se reinició ni se ha demostrado ejecución física todavía.**

## Primera prueba manual

1. Guarda tu trabajo y reinicia manualmente.
2. Pulsa F11 durante el encendido y selecciona **Orquestador del Metal (prueba)**.
3. Fotografía el resultado completo, incluido cualquier motivo de error.

En caso de éxito aparecerá:

```text
METAL64: BootServices cerrados.
Hola mundo desde mi .hex!
Programa propio retorno. CPU detenida.
```

La detención final es intencional. Aún no hay teclado/eco interactivo después de
salir de los servicios de arranque. Reinicia manualmente y selecciona Windows Boot
Manager para volver a Windows. Si no aparece la entrada nueva o falla su carga,
registra ese resultado; instalar y registrar no garantiza aceptación por la placa.

Para retirar solamente la entrada nueva, en PowerShell con permisos suficientes:

```powershell
bcdedit /delete '{57cb1745-7f84-11f1-930d-c3a2d7ca848a}'
```

No ejecutes la utilidad de registro de nuevo para retirar la entrada. Los dos
archivos quedan en A: y no afectan a las rutas anteriores de arranque.

[Guía y límites del puente](../../../Puente_Metal/LEEME.md).
