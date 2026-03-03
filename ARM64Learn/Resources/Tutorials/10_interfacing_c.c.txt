// C calling Assembly function
// Demonstrates full C ↔ Assembly interop on macOS ARM64
#include <stdio.h>
#include <stdint.h>

// Declaration of our assembly function
// (implemented below as inline asm for single-file demo)
static inline int64_t arm64_multiply_add(int64_t a, int64_t b, int64_t c) {
    int64_t result;
    // Inline ARM64 assembly: result = a * b + c
    __asm__ volatile (
        "madd %0, %1, %2, %3"   // result = a * b + c
        : "=r"(result)
        : "r"(a), "r"(b), "r"(c)
    );
    return result;
}

int main(void) {
    printf("C ↔ ARM64 Assembly Interop Demo\n");
    printf("================================\n\n");

    // Test our assembly function
    int64_t a = 10;
    int64_t b = 20;
    int64_t c = 5;

    int64_t result = arm64_multiply_add(a, b, c);

    printf("arm64_multiply_add(%lld, %lld, %lld) = %lld\n", a, b, c, result);
    printf("Expected: %lld * %lld + %lld = %lld\n", a, b, c, a * b + c);

    // Demonstrate ABI - arguments in x0, x1, x2, ...
    printf("\nARM64 ABI:\n");
    printf("- Arguments passed in x0-x7 (w0-w7 for 32-bit)\n");
    printf("- Return value in x0 (w0 for 32-bit)\n");
    printf("- x19-x28 are callee-saved\n");
    printf("- x29 is frame pointer (fp)\n");
    printf("- x30 is link register (lr)\n");

    return 0;
}
