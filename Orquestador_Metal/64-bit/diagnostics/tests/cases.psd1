@{
    divide = @{ Vector=0; Rip=0xF1809; Error=0; Cr2=0; Frame=0x8FFC8; Cause='divide error (#DE)' }
    invalid = @{ Vector=6; Rip=0xF1800; Error=0; Cr2=0; Frame=0x8FFC8; Cause='invalid opcode (#UD)' }
    page = @{ Vector=14; Rip=0xF1805; Error=0; Cr2=0x200000; Frame=0x8FFC8; Cause='page fault (#PF)' }
    general = @{ Vector=13; Rip=0xF1804; Error=0x30; Cr2=0; Frame=0x8FFC8; Cause='general protection (#GP)' }
    double = @{ Vector=8; Rip=0xF1810; Error=0; Cr2=0; Frame=0x87FC8; Cause='double fault (#DF)' }
    write = @{ Vector=14; Rip=0xF1805; Error=3; Cr2=0xF0000; Frame=0x8FFC8; Cause='page fault (#PF)' }
    execute = @{ Vector=14; Rip=0xA000; Error=0x11; Cr2=0xA000; Frame=0x8FFC8; Cause='page fault (#PF)' }
    guard = @{ Vector=14; Rip=0xF1805; Error=2; Cr2=0x8E000; Frame=0x8FFC8; Cause='page fault (#PF)' }
    stack = @{ Vector=8; Rip=0xF1805; Error=0; Cr2=0x8EFF8; Frame=0x87FC8; Cause='double fault (#DF)' }
}
