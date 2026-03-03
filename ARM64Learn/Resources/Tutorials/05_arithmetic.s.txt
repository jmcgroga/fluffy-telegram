// ARM64 Arithmetic
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Basic arithmetic
    mov     x0, #100
    mov     x1, #37

    add     x2, x0, x1          // x2 = 137
    sub     x3, x0, x1          // x3 = 63
    mul     x4, x0, x1          // x4 = 3700

    // Division (unsigned and signed)
    mov     x5, #20
    udiv    x6, x0, x5          // x6 = 100 / 20 = 5
    sdiv    x7, x0, x5          // x7 = 100 / 20 = 5

    // Remainder via MSUB
    udiv    x8, x0, x1          // x8 = 100 / 37 = 2
    msub    x9, x8, x1, x0      // x9 = 100 - (2 * 37) = 26 (remainder)

    // Negation
    neg     x10, x1             // x10 = -37

    // Shifts
    lsl     x11, x0, #2         // x11 = 100 << 2 = 400
    lsr     x12, x0, #1         // x12 = 100 >> 1 = 50
    asr     x13, x10, #2        // x13 = -37 >> 2 (arithmetic) = -10

    // Increment/decrement patterns
    add     x14, x0, #1         // x14 = x0 + 1
    sub     x15, x0, #1         // x15 = x0 - 1

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret
