# Flappy Metal: prueba visual instalada en A: BMO

Preparación e instalación del 18 de octubre de 2026. Windows enumeró teclados
USB/HID y el usuario confirmó que solo dispone de USB. El juego interactivo
controla PS/2 y PIT en QEMU; no se lo presenta como compatible con el teclado USB
real. Por eso esta primera prueba física contiene únicamente el dibujo estático.

## Estado comprobado

- [Paquete](paquete.json): entrada EFI separada y escena de 1300 bytes.
- [Prueba QEMU](qemu-preview.json): salida de BootServices, código exacto en RAM y
  1.024.000 píxeles comparados con la escena esperada. Se usa la nueva ruta FLAPPY.X86.
- [Instalación](instalacion.json) y [verificación](verificacion.json): huellas
  instaladas coincidentes, saludo anterior intacto, registro idempotente sin duplicados.
- [Entrada](entrada.json): añadida al final y orden anterior conservado; contiene
  las listas de identificadores previas y posteriores a la instalación.
- [Firmware observado](firmware-observado.txt): lectura posterior a la instalación.

No se ha reiniciado el equipo ni se ha observado todavía este dibujo en la placa.
No se ha modificado la flash BIOS, el tipo de partición ni las rutas de Windows.
Los archivos del saludo anterior conservan las huellas de la [línea base](baseline.json).

| Elemento | Valor |
|---|---|
| Entrada | Flappy Metal (prueba visual) |
| ID | {57cb1746-7f84-11f1-930d-c3a2d7ca848a} |
| EFI | A:\EFI\ORQUESTADOR\FLAPPY.EFI |
| Programa | A:\METAL\FLAPPY.X86 |
| Control | Solo imagen; sin movimiento ni teclado |

## Primera prueba manual

1. Guarda tu trabajo y reinicia manualmente.
2. Pulsa F11 y elige **Flappy Metal (prueba visual)**.
3. Debe aparecer el pájaro, las tuberías y el suelo, centrados sobre un borde oscuro.
4. Toma una foto de toda la pantalla, incluso si aparece un error.
5. La imagen queda fija porque la CPU se detiene intencionalmente. Reinicia
   manualmente y elige Windows Boot Manager para regresar.

Espacio y Enter no juegan en esta versión. La foto confirmará solo el dibujo en
el hardware real; el controlador USB y la prueba interactiva siguen pendientes.

Esta es la [referencia obtenida con el mismo paquete bajo QEMU](qemu-preview.png):

![Referencia virtual; pendiente foto física](qemu-preview.png)

## Cómo se preparó y cómo retirar la entrada

El constructor cambia solo dos literales UTF-16 del EFI probado: la ruta del
programa y su error de lectura. Verifica que las instrucciones y fuente gráfica
permanezcan idénticas. La escena también queda fijada a su SHA-256 revisado.
[Procedimiento reproducible](../../../Games/Flappy_Metal/PC-PREVIEW.md).

Si se desea retirar solamente esta entrada, en PowerShell con permisos suficientes:

```powershell
bcdedit /delete '{57cb1746-7f84-11f1-930d-c3a2d7ca848a}'
```

Los archivos separados pueden quedar en A:; no alteran las rutas anteriores.
La prueba del juego QEMU sigue disponible con `jugar.ps1`.
