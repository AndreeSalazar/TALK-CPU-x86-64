@{
    SchemaVersion = 1
    RomBytes = 0x10000
    MappedBytes = 0x200000
    WarningPercent = 80
    RequiredMemory = @('PML4','PDPT','PD','PT','GDT','TSS','IDT','AllocatorState','ProgramPage','GuardMain','StackMain','ROM','WorkRAM')
    MemoryContracts = @(
        @{Name='ProgramPage';Start=0x80000;End=0x81000}
        @{Name='PT';Start=0x4000;End=0x5000}
        @{Name='TSS';Start=0x7000;End=0x7068}
        @{Name='IDT';Start=0x8000;End=0x9000}
        @{Name='AllocatorState';Start=0x9000;End=0x9020}
        @{Name='GuardMain';Start=0x8E000;End=0x8F000}
        @{Name='StackMain';Start=0x8F000;End=0x90000}
        @{Name='ROM';Start=0xF0000;End=0x100000}
    )
    Contracts = @(
        @{Source='64-bit\programs\loader.hex';Offset=0x3CB7;Bytes='C7 04 25 00 44 00 00 01 00 08 00';Why='Quitar escritura antes de permitir ejecutar la pagina del programa.'}
        @{Source='64-bit\programs\loader.hex';Offset=0x3CE6;Bytes='C7 04 25 04 44 00 00 00 00 00 80';Why='Restaurar NX antes de devolver escritura al regresar del programa.'}
        @{Source='16-bit\reset.hex';Offset=0xFFF0;Bytes='EA 00 00 00 F0';Why='La CPU debe saltar a nuestra entrada de reset.'}
        @{Source='32-bit\to-64.hex';Offset=0x02DB;Bytes='0D 00 09 00 00';Why='LME y NXE deben activarse juntos.'}
        @{Source='32-bit\to-64.hex';Offset=0x02E5;Bytes='0D 00 00 01 80';Why='La paginacion y CR0.WP protegen el codigo incluso en supervisor.'}
        @{Source='64-bit\services\table.hex';Offset=0x2608;Bytes='02 00 00 00';Why='La version 2 requiere cursor, complemento y bloqueo.'}
        @{Source='64-bit\services\table.hex';Offset=0x2620;Bytes='00 24 0F 00 00 00 00 00';Why='El ABI debe apuntar a allocate, no a datos o a otra instruccion.'}
        @{Source='64-bit\services\allocate.hex';Offset=0x2478;Bytes='49 81 F9 00 00 18 00';Why='El extremo calculado debe compararse con el limite exclusivo de la arena.'}
    )
    # Ventanas [Start,End): ningun archivo puede crecer en el carril siguiente.
    Sources = @{
        '64-bit\programs\loader.hex' = @{Start=0x3C00;End=0x4000;Why='Validacion, copia y permisos del binario crudo'}
        '64-bit\programs\hola-header.hex' = @{Start=0x4000;End=0x4018;Fixed=$true;Why='Cabecera del hola mundo'}
        '64-bit\programs\hola.hex' = @{Start=0x4018;End=0x5000;Why='Binario propio hola mundo'}
        '64-bit\programs\eco-header.hex' = @{Start=0x5000;End=0x5018;Fixed=$true;Why='Cabecera del eco'}
        '64-bit\programs\eco.hex' = @{Start=0x5018;End=0x6000;Why='Binario propio eco'}
        '64-bit\monitor\console.hex' = @{Start=0x3000;End=0x3C00;Why='Consola UART con transmision acotada y comandos fijos'}
        '64-bit\services\target-monitor.hex' = @{Start=0x22F0;End=0x2300;Why='Destino exclusivo del monitor'}
        '64-bit\services\state-init.hex' = @{Start=0x2A00;End=0x2B00;Why='Inicializar cursor, espejo y bandera'}
        '64-bit\services\latch-test.hex' = @{Start=0x2B00;End=0x2C00;Why='Probar bloqueo persistente por corrupcion'}
        '64-bit\services\latch-message.hex' = @{Start=0x2C00;End=0x2D00;Why='Confirmacion del guardian de estado'}
        '64-bit\services\transition.hex' = @{Start=0x043D;End=0x0480;Why='Paso comun hacia los servicios'}
        '64-bit\services\self-test.hex' = @{Start=0x2000;End=0x22F0;Why='Autoprueba y salidas de servicios'}
        '64-bit\services\target-normal.hex' = @{Start=0x22F0;End=0x2300;Why='Destino exclusivo tras servicios'}
        '64-bit\services\target-stress.hex' = @{Start=0x22F0;End=0x2300;Why='Destino exclusivo tras servicios'}
        '64-bit\services\target-exception.hex' = @{Start=0x22F0;End=0x2300;Why='Destino exclusivo tras servicios'}
        '64-bit\services\allocate.hex' = @{Start=0x2400;End=0x2600;Why='Asignacion con limites comprobados'}
        '64-bit\services\table.hex' = @{Start=0x2600;End=0x2700;Why='Contrato de servicio versionado'}
        '64-bit\services\messages.hex' = @{Start=0x2700;End=0x2800;Why='Estado del servicio de memoria'}
        '64-bit\services\cases.hex' = @{Start=0x2800;End=0x2900;Why='Casos de autoprueba'}
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
        @{Name='ProgramPage';Start=0x80000;End=0x81000;Alignment=0x1000;Why='Pagina dedicada: RW/NX durante copia, RX durante ejecucion'}
        @{Name='NullGuard';Start=0;End=0x1000;Alignment=0x1000;Why='Atrapar punteros nulos'}
        @{Name='PML4';Start=0x1000;End=0x2000;Alignment=0x1000;Why='Raiz de paginacion'}
        @{Name='PDPT';Start=0x2000;End=0x3000;Alignment=0x1000;Why='Paginacion nivel 3'}
        @{Name='PD';Start=0x3000;End=0x4000;Alignment=0x1000;Why='Paginacion nivel 2'}
        @{Name='PT';Start=0x4000;End=0x5000;Alignment=0x1000;Why='Permisos por pagina de 4 KiB'}
        @{Name='GDT';Start=0x6000;End=0x6030;Alignment=16;Why='Descriptores en RAM escribible'}
        @{Name='BootStack16';Start=0x6800;End=0x7000;Alignment=16;Why='Reserva temporal de pila real'}
        @{Name='TSS';Start=0x7000;End=0x7068;Alignment=16;Why='Punteros de pilas de excepciones'}
        @{Name='IDT';Start=0x8000;End=0x9000;Alignment=0x1000;Why='Puertas de excepcion'}
        @{Name='AllocatorState';Start=0x9000;End=0x9020;Alignment=16;Why='Cursor, complemento y bandera persistente'}
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
        @{Name='WorkRAM';Start=0x100000;End=0x200000;Alignment=0x1000;Why='Arena de memoria y RAM de prueba, usadas secuencialmente'}
    )
}
