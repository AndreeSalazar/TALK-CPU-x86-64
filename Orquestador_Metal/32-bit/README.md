# Etapa 2: 32 bits

Entrada: direccion F0200, CS=08, CR0.PE=1, CR0.PG=0, A20 activa,
interrupciones enmascarables desactivadas. La etapa de 16 bits instalo la GDT.

`entry.hex` recarga DS/ES/SS/FS/GS con el selector plano 10 y fija
ESP=90000. Luego emite `message.hex`. Desde ahi se elige una de dos salidas:

- `halt.hex`: detener la variante de 32 bits, sin habilitar paginacion.
- `to-64.hex`: borrar cuatro paginas de RAM en 1000-4FFF, construir PML4,
  PDPT, PD y PT, habilitar PAE, cargar CR3, activar EFER.LME/NXE y CR0.PG/WP.
  Despues salta al selector 18 con destino F1000, que instala el diagnostico
  de excepciones antes de continuar a F0400.

PML4[0] apunta a PDPT en 2000, PDPT[0] a PD en 3000 y PD[0] a PT en
4000. Las 512 entradas de PT describen paginas de 4 KiB hasta 200000,
con datos RW/NX, ROM RX y paginas nula y de guarda no presentes.
Las demas entradas de los niveles superiores quedan a cero.

Activar CR0.PG permite long mode, pero el salto final selecciona
el segmento con L=1 y D=0 para decodificar instrucciones de 64 bits.
RDMSR modifica EDX:EAX: la etapa siguiente configura otra vez el puerto DX.

Contrato de salida: CS=18, CR0.PE=1, PG=1 y WP=1, CR4.PAE=1, CR3=1000,
EFER.LME/LMA/NXE activos y las paginas permitidas por identidad en el primer
tramo de 2 MiB. Las guardas y la pagina nula no estan presentes. La entrada larga
vuelve a fijar RSP antes de usar su pila.
La GDT y los destinos inmediatos siguen en regiones mapeadas.

Probar desde la raiz: `.\run-firmware.ps1 -Stage 32 -Check`.
Incluye la preparacion de 16 bits y excluye la carpeta de 64 bits.
Las direcciones, valores de registros y selectores estan en hexadecimal.
