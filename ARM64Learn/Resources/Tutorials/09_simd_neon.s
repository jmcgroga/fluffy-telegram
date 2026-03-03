// ARM64 NEON / SIMD Introduction
// Computes dot product of two 4-element float arrays using SIMD
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Load addresses of a[] and b[]
    adrp    x0, vec_a@PAGE
    add     x0, x0, vec_a@PAGEOFF
    adrp    x1, vec_b@PAGE
    add     x1, x1, vec_b@PAGEOFF

    // Load 4 floats from each array into NEON registers
    ld1     {v0.4s}, [x0]       // v0 = {1.0, 2.0, 3.0, 4.0}
    ld1     {v1.4s}, [x1]       // v1 = {5.0, 6.0, 7.0, 8.0}

    // Multiply element-wise: v2 = v0 * v1
    fmul    v2.4s, v0.4s, v1.4s // v2 = {5.0, 12.0, 21.0, 32.0}

    // Sum all lanes: s3 = v2[0] + v2[1] + v2[2] + v2[3]
    faddp   v3.4s, v2.4s, v2.4s // Pairwise add
    faddp   v3.4s, v3.4s, v3.4s // Final pairwise add
    // v3[0] now contains the dot product = 70.0

    // Alternative: horizontal add
    // addv s4, v2.4s           // Sum all lanes into s4

    // Store result (just to demonstrate)
    adrp    x2, result@PAGE
    add     x2, x2, result@PAGEOFF
    str     s3, [x2]

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret

.data
    .align  4
vec_a:
    .float  1.0, 2.0, 3.0, 4.0
vec_b:
    .float  5.0, 6.0, 7.0, 8.0
result:
    .float  0.0
