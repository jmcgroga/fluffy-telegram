// ARM64 Hello World - Minimal macOS program
// Demonstrates: function prologue/epilogue, calling C functions, string literals
.global _main
.align  2

.data
hello_msg:
    .asciz  "Hello, ARM64 World!"

.text
_main:
    // Prologue: save frame pointer and link register
    stp     x29, x30, [sp, #-16]!   // Push {fp, lr}, pre-decrement sp by 16
    mov     x29, sp                 // Set up frame pointer

    // Load address of string using PC-relative addressing
    adrp    x0, hello_msg@PAGE      // x0 = page containing hello_msg
    add     x0, x0, hello_msg@PAGEOFF   // x0 = exact address of hello_msg

    // Call C library function puts(char *s)
    bl      _puts                   // Branch with link to _puts

    // Return value: 0 for success
    mov     w0, #0                  // Exit code 0

    // Epilogue: restore registers and return
    ldp     x29, x30, [sp], #16     // Pop {fp, lr}, post-increment sp by 16
    ret                             // Return to caller (uses x30)
