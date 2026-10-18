@{
    RomBytes = 0x10000
    MappedBytes = 0x200000
    WarningPercent = 80
    # Ventanas [Start,End): ningun archivo puede crecer en el carril siguiente.
    Sources = @{
        '16-bit\entry.hex' = @{Start=0x0000;End=0x0024;Fixed=$true;Why='Entrada real antes de la transicion'}
        '16-bit\to-32.hex' = @{Start=0x0024;End=0x0080;Why='Transicion real a protegido'}
        '16-bit\halt.hex' = @{Start=0x0024;End=0x0080;Why='Salida exclusiva de la variante 16'}
        '16-bit\message.hex' = @{Start=0x0080;End=0x00F0;Why='Texto antes del puntero GDT'}
        '16-bit\gdt.hex' = @{Start=0x00F0;End=0x0200;Why='GDT inicial y puntero'}
        '32-bit\entry.hex' = @{Start=0x0200;End=0x0225;Fixed=$true;Why='Entrada protegida antes de paginacion'}
        '32-bit\to-64.hex' = @{Start=0x0225;End=0x0380;Why='Tablas, permisos y entrada larga'}
        '32-bit\halt.hex' = @{Start=0x0225;End=0x0380;Why='Salida exclusiva de la variante 32'}
        '32-bit\message.hex' = @{Start=0x0380;End=0x0400;Why='Texto de 32 bits'}
        '64-bit\entry.hex' = @{Start=0x0400;End=0x043D;Fixed=$true;Why='Comprobacion de registros largos'}
        '64-bit\halt.hex' = @{Start=0x043D;End=0x0480;Why='Salida normal de 64'}
        '64-bit\stress\transition.hex' = @{Start=0x043D;End=0x0480;Why='Salida exclusiva hacia RAM'}
        '64-bit\diagnostics\tests\transition.hex' = @{Start=0x043D;End=0x0480;Why='Salida exclusiva hacia prueba de CPU'}
        '64-bit\failure.hex' = @{Start=0x0480;End=0x0500;Why='Fallo de la comprobacion R8'}
        '64-bit\message.hex' = @{Start=0x0500;End=0x0600;Why='Mensajes de modo largo y guardianes'}
        '64-bit\stress\fill.hex' = @{Start=0x0600;End=0x0640;Why='Llenado de RAM'}
        '64-bit\stress\clean.hex' = @{Start=0x0640;End=0x0660;Why='Camino normal exclusivo de RAM'}
        '64-bit\stress\corrupt.hex' = @{Start=0x0640;End=0x0660;Why='Corrupcion intencional exclusiva de RAM'}
        '64-bit\stress\verify.hex' = @{Start=0x0660;End=0x0900;Why='Lectura, inversion y resultado RAM'}
        '64-bit\stress\messages.hex' = @{Start=0x0900;End=0x1000;Why='Textos de prueba RAM'}
        '64-bit\diagnostics\init.hex' = @{Start=0x1000;End=0x1200;Why='Instalar TSS e IDT antes de ejecutar cuerpo'}
        '64-bit\diagnostics\stubs.hex' = @{Start=0x1200;End=0x1500;Why='Entradas de excepciones'}
        '64-bit\diagnostics\handler.hex' = @{Start=0x1500;End=0x1700;Why='Captura de marco y diagnostico'}
        '64-bit\diagnostics\output.hex' = @{Start=0x1700;End=0x1800;Why='Salida de texto y valores'}
        '64-bit\diagnostics\messages.hex' = @{Start=0x1A00;End=0x1F00;Why='Causas y tabla de nombres'}
        '64-bit\diagnostics\pointers.hex' = @{Start=0x1F00;End=0x2000;Why='Punteros GDTR e IDTR'}
        '16-bit\reset.hex' = @{Start=0xFFF0;End=0x10000;Why='Vector fijo de reset'}
        '64-bit\diagnostics\tests\divide.hex' = @{Start=0x1800;End=0x1A00;Why='Disparador exclusivo'}
        '64-bit\diagnostics\tests\invalid.hex' = @{Start=0x1800;End=0x1A00;Why='Disparador exclusivo'}
        '64-bit\diagnostics\tests\page.hex' = @{Start=0x1800;End=0x1A00;Why='Disparador exclusivo'}
        '64-bit\diagnostics\tests\general.hex' = @{Start=0x1800;End=0x1A00;Why='Disparador exclusivo'}
        '64-bit\diagnostics\tests\double.hex' = @{Start=0x1800;End=0x1A00;Why='Disparador exclusivo'}
        '64-bit\diagnostics\tests\write.hex' = @{Start=0x1800;End=0x1A00;Why='Escritura prohibida en ROM'}
        '64-bit\diagnostics\tests\execute.hex' = @{Start=0x1800;End=0x1A00;Why='Ejecucion prohibida en datos'}
        '64-bit\diagnostics\tests\guard.hex' = @{Start=0x1800;End=0x1A00;Why='Acceso prohibido a guarda de pila'}
        '64-bit\diagnostics\tests\stack.hex' = @{Start=0x1800;End=0x1A00;Why='Cruce real de pila hacia guarda'}
    }
    Memory = @(
        @{Name='NullGuard';Start=0;End=0x1000;Alignment=0x1000;Why='Atrapar punteros nulos'}
        @{Name='PML4';Start=0x1000;End=0x2000;Alignment=0x1000;Why='Raiz de paginacion'}
        @{Name='PDPT';Start=0x2000;End=0x3000;Alignment=0x1000;Why='Paginacion nivel 3'}
        @{Name='PD';Start=0x3000;End=0x4000;Alignment=0x1000;Why='Paginacion nivel 2'}
        @{Name='PT';Start=0x4000;End=0x5000;Alignment=0x1000;Why='Permisos por pagina de 4 KiB'}
        @{Name='GDT';Start=0x6000;End=0x6030;Alignment=16;Why='Descriptores en RAM escribible'}
        @{Name='BootStack16';Start=0x6800;End=0x7000;Alignment=16;Why='Reserva temporal de pila real'}
        @{Name='TSS';Start=0x7000;End=0x7068;Alignment=16;Why='Punteros de pilas de excepciones'}
        @{Name='IDT';Start=0x8000;End=0x9000;Alignment=0x1000;Why='Puertas de excepcion'}
        @{Name='GuardMC';Start=0x82000;End=0x83000;Alignment=0x1000;Why='Limite inferior de IST3'}
        @{Name='StackMC';Start=0x83000;End=0x84000;Alignment=0x1000;Why='Pila IST3'}
        @{Name='GuardNMI';Start=0x84000;End=0x85000;Alignment=0x1000;Why='Limite inferior de IST2'}
        @{Name='StackNMI';Start=0x85000;End=0x86000;Alignment=0x1000;Why='Pila IST2'}
        @{Name='GuardDF';Start=0x86000;End=0x87000;Alignment=0x1000;Why='Limite inferior de IST1'}
        @{Name='StackDF';Start=0x87000;End=0x88000;Alignment=0x1000;Why='Pila IST1 para doble fallo'}
        @{Name='GuardMain';Start=0x8E000;End=0x8F000;Alignment=0x1000;Why='Limite inferior de pila normal'}
        @{Name='StackMain';Start=0x8F000;End=0x90000;Alignment=0x1000;Why='Pila normal de 64 bits'}
        @{Name='DeviceWindow';Start=0xA0000;End=0xF0000;Alignment=0x1000;Why='No asignar RAM sobre area de dispositivos PC'}
        @{Name='ROM';Start=0xF0000;End=0x100000;Alignment=0x1000;Why='Codigo y constantes solo lectura'}
        @{Name='StressRAM';Start=0x100000;End=0x200000;Alignment=0x1000;Why='Datos exclusivos de prueba'}
    )
}
