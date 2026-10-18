# Modelo de Orquestador del Metal

Hoy se escriben instrucciones x86 en `.hex`. El constructor copia esos bytes
a una ROM y los guardianes verifican ventanas, reservas y contratos especificos.
La CPU virtual comienza en RESET y ejecuta las instrucciones. Los servicios
de memoria, pantalla y entrada tambien son codigo del firmware.

Esto es programacion directa en codigo maquina con construccion y comprobacion
automatizadas. Evita ensamblador, compilador de lenguaje y linker para producir
las instrucciones actuales, aunque utiliza herramientas para copiar y verificar
los bytes y QEMU para probarlos. `.hex` es su representacion textual; la CPU
ejecuta los bytes binarios de la ROM, no interpreta el texto hexadecimal.

"Compilador Sintetico Directo al Metal" puede nombrar una evolucion futura:
un lenguaje de operaciones, tipos y contratos que una herramienta traduzca a
bytes exactos, explicando cada rechazo y verificando sus limites. Para llamarlo
compilador semantico habria que implementar esa traduccion; los guardianes actuales
no interpretan aun toda la semantica de las instrucciones ni equivalen a C.

Mantener cada byte controlado es compatible con esa idea. Por ahora el proyecto
conserva la autoria manual de las instrucciones y no introduce ese compilador.
