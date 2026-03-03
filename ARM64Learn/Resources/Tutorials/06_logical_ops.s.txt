// ARM64 Logical Operations
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    mov     x0, #0b11001010    // x0 = 0xCA = 0b11001010
    mov     x1, #0b10110101    // x1 = 0xB5 = 0b10110101

    // Basic bitwise
    and     x2, x0, x1         // x2 = 0b10000000 = 0x80
    orr     x3, x0, x1         // x3 = 0b11111111 = 0xFF
    eor     x4, x0, x1         // x4 = 0b01111111 = 0x7F

    // Bit clear (AND NOT)
    bic     x5, x0, x1         // x5 = x0 & ~x1 = 0b01001010

    // Complement
    mvn     x6, x0             // x6 = ~x0

    // Logical shift left/right
    lsl     x7, x0, #1         // x7 = x0 << 1
    lsr     x8, x0, #1         // x8 = x0 >> 1

    // Rotate right
    ror     x9, x0, #4         // Rotate x0 right by 4 bits

    // Test bits (TST = ANDS, discards result, sets flags)
    mov     x10, #0x8
    tst     x0, x10            // Test if bit 3 is set in x0

    // Bit field operations
    mov     x11, #0xFF
    ubfx    x12, x11, #2, #4   // Extract 4 bits starting at bit 2
    bfi     x13, x11, #4, #8   // Insert 8 bits of x11 into x13 at bit 4

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret
