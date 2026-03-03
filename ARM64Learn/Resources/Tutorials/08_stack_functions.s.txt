// ARM64 Stack and Functions
// Demonstrates: calling convention, prologue/epilogue, callee-saved regs
.global _main
.align  2
.text

// int add_three(int a, int b, int c)  → a + b + c
// Args: w0, w1, w2 | Return: w0
add_three:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    add     w0, w0, w1          // w0 = a + b
    add     w0, w0, w2          // w0 = (a+b) + c
    ldp     x29, x30, [sp], #16
    ret

// int factorial(int n)
// Uses recursion, demonstrates BL instruction
factorial:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     w0, [sp, #16]       // Save n

    cmp     w0, #1
    b.le    .Lbase              // if n <= 1, return 1

    sub     w0, w0, #1          // n - 1
    bl      factorial           // Recursive call: factorial(n-1)
    ldr     w1, [sp, #16]       // Restore n
    mul     w0, w0, w1          // result = factorial(n-1) * n
    b       .Lfact_end

.Lbase:
    mov     w0, #1              // Base case: return 1

.Lfact_end:
    ldp     x29, x30, [sp], #32
    ret

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Call add_three(10, 20, 30)
    mov     w0, #10
    mov     w1, #20
    mov     w2, #30
    bl      add_three           // x0 = 60

    // Call factorial(5)
    mov     w0, #5
    bl      factorial           // x0 = 120

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret
