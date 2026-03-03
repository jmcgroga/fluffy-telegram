// ARM64 Branches & Control Flow
// Demonstrates: if/else, loop, switch-like pattern
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // --- if / else ---
    mov     x0, #42
    cmp     x0, #50
    b.ge    .Lbig          // if x0 >= 50, jump to .Lbig
    // else: x0 < 50
    mov     x1, #1
    b       .Lafter_if
.Lbig:
    mov     x1, #2
.Lafter_if:
    // x1 now holds 1 or 2

    // --- Loop (count from 0 to 9) ---
    mov     x2, #0         // counter
    mov     x3, #10        // limit
.Lloop:
    // Loop body (just increment a value)
    add     x4, x4, x2     // x4 += counter
    add     x2, x2, #1     // counter++
    cmp     x2, x3
    b.lt    .Lloop         // if counter < 10, repeat

    // --- Switch-like pattern ---
    mov     x5, #2
    cmp     x5, #0
    b.eq    .Lcase0
    cmp     x5, #1
    b.eq    .Lcase1
    cmp     x5, #2
    b.eq    .Lcase2
    b       .Ldefault

.Lcase0:
    mov     x6, #100
    b       .Lswitch_end
.Lcase1:
    mov     x6, #200
    b       .Lswitch_end
.Lcase2:
    mov     x6, #300
    b       .Lswitch_end
.Ldefault:
    mov     x6, #0
.Lswitch_end:

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret
