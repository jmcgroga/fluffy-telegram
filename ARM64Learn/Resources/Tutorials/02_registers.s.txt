// ARM64 Register Demonstration
// Shows: register naming, 32-bit vs 64-bit, special registers
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Move immediate values into registers
    mov     x0, #42          // x0 = 42
    mov     x1, #100         // x1 = 100

    // 32-bit write zeroes upper 32 bits
    mov     w2, #0xDEAD      // w2 = 0xDEAD,  x2 = 0x000000000000DEAD

    // Arithmetic using registers
    add     x3, x0, x1       // x3 = x0 + x1 = 142
    sub     x4, x1, x0       // x4 = x1 - x0 = 58
    mul     x5, x0, x1       // x5 = x0 * x1 = 4200

    // Using special registers
    mov     x6, sp           // x6 = current stack pointer
    mov     x7, x29          // x7 = frame pointer (same as sp here)

    // Demonstrate x30 (link register) - saved by prologue
    // x30 contains return address from caller

    // Return 0
    mov     w0, #0

    ldp     x29, x30, [sp], #16
    ret
