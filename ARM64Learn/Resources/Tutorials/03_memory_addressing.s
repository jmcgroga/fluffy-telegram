// ARM64 Memory Addressing Modes
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-48]!   // Pre-index: allocate 48 bytes
    mov     x29, sp

    // --- Base + offset ---
    adrp    x0, myArray@PAGE
    add     x0, x0, myArray@PAGEOFF // x0 = &myArray[0]

    ldr     x1, [x0]                // Load element [0] = 10
    ldr     x2, [x0, #8]            // Load element [1] = 20
    ldr     x3, [x0, #16]           // Load element [2] = 30

    // --- Pre-index: adjust address before access ---
    ldr     x4, [x0, #24]!          // Load element [3], then x0 += 24

    // --- Post-index: adjust address after access ---
    ldr     x5, [x0], #8            // Load from x0, then x0 += 8

    // --- Store to stack (local variables) ---
    str     x1, [sp, #16]           // Store x1 to stack
    str     x2, [sp, #24]
    str     x3, [sp, #32]

    // Load them back
    ldr     x6, [sp, #16]
    ldr     x7, [sp, #24]

    mov     w0, #0
    ldp     x29, x30, [sp], #48
    ret

.data
    .align  3
myArray:
    .quad   10, 20, 30, 40, 50
