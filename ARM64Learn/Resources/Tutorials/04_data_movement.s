// ARM64 Data Movement
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp

    // --- Immediate loads ---
    mov     x0, #0xFF           // Small immediate
    mov     x0, #0x1000         // Larger immediate (still fits)

    // 64-bit constant via MOVZ/MOVK
    movz    x1, #0xDEAD
    movk    x1, #0xBEEF, lsl #16
    movk    x1, #0xCAFE, lsl #32
    movk    x1, #0xFACE, lsl #48
    // x1 now contains 0xFACE_CAFE_BEEF_DEAD

    // --- Load from memory ---
    adrp    x2, value@PAGE
    add     x2, x2, value@PAGEOFF
    ldr     x3, [x2]            // x3 = value from memory

    // --- Store to memory ---
    mov     x4, #9999
    str     x4, [sp, #16]       // Store to stack

    // --- Register-to-register move ---
    mov     x5, x3              // Copy x3 to x5

    mov     w0, #0
    ldp     x29, x30, [sp], #32
    ret

.data
value:
    .quad   0x123456789ABCDEF0
