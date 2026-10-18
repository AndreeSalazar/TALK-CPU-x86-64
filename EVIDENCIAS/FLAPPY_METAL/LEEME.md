# Flappy Metal: primera escena en QEMU

Pruebas del 18 de octubre de 2026. Es el primer paso gráfico, no un juego ya
jugable. La CPU dibuja 38 rectángulos después de ExitBootServices, usando el
framebuffer que dejó inicializado el firmware virtual. No se usa una API gráfica
del sistema anfitrión para producir el dibujo del invitado.

![Escena capturada desde QEMU](01-scene.png)

La captura procede de QMP screendump; no fue generada ni retocada. El framebuffer
es BGR de 32 bits, 1280×800 con stride 1280. Se compararon exactamente 1.024.000
píxeles contra una referencia de rectángulos independiente del código máquina.
La escena tiene un lienzo de 640×360 centrado y un borde oscuro.

| Informe | Resultado |
|---|---|
| [Normal](test-normal.json) | Salida de BootServices, ejecución CPL0, copia exacta del cuerpo en RAM, testigo de escena lista y píxeles exactos |
| [Coordenada inválida](test-outside.json) | Desbordamiento al centrar rechazado; solo el fondo inicial válido fue dibujado |
| [Ancho cero](test-empty.json) | Rectángulo vacío rechazado; solo el fondo inicial válido fue dibujado |

La prueba de coordenada inválida reveló un desbordamiento en la primera versión;
se añadió el rechazo antes de dibujar y los tres casos finales pasaron. No se
afirma que estas tres pruebas cubran todas las averías ni todos los modos de vídeo.

El [informe del paquete](scene-normal.json) registra 1300 bytes, de los cuales
1276 son cuerpo. Las instrucciones están escritas a mano en
[scene.hex](../../Games/Flappy_Metal/scene.hex); Python empaqueta instrucciones
existentes y datos geométricos. No se presenta como salida del compilador CASM.
No hay movimiento, reloj, entrada ni colisiones en esta entrega. El programa
termina en su propio bucle HLT con la imagen visible; no retorna al texto del puente.

La imagen virtual se ejecutó con snapshot y se verificó que su SHA-256 no cambió.
No se instaló la escena en A: ni se hizo una nueva prueba física. El saludo real
anterior y sus fotografías permanecen separados. [Manifiesto](manifiesto.json).

La reorganización movió 26 archivos a tools/docs y fusionó dos guías repetidas
en Orquestador_Metal/README.md. La [regresión posterior](regression-layout.json)
registra ROM, guardianes, programas, pantalla, FAT32, GPT, arranque, puente,
CASM y análisis MSI aprobados con las nuevas rutas.

Desde la raíz:

```powershell
.\jugar.ps1 -Comprobar
.\jugar.ps1
```
