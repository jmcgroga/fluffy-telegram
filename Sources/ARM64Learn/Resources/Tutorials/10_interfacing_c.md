# Interfacing with C

One of the most practical skills is calling C functions from assembly and writing assembly routines callable from C. This is how you write optimized hot paths while keeping the rest of your codebase in a high-level language.

## Calling C Functions from Assembly

Any C function can be called from ARM64 assembly. The rules are simple:

1. Put arguments in `x0`–`x7` per the calling convention
2. Use `BL _functionname` (note underscore prefix on macOS)
3. Return value comes back in `x0` (or `v0` for FP)
4. Assume `x0`–`x15` are destroyed by the call

```arm64
// Call: printf("Value: %lld\n", 42)
ADRP  x0, fmt@PAGE
ADD   x0, x0, fmt@PAGEOFF   // First arg: format string
MOV   x1, #42               // Second arg: integer
BL    _printf               // Call printf (libc)

.data
fmt: .asciz "Value: %lld\n"
```

## Writing Assembly Functions Callable from C

In C, declare the function with `extern`:
```c
extern int64_t fast_sum(const int64_t *array, int64_t count);
```

In assembly (macOS requires the underscore prefix):
```arm64
.global _fast_sum
_fast_sum:
    // x0 = array pointer, x1 = count
    MOV  x2, xzr            // sum = 0
    CBZ  x1, .Ldone         // if count == 0, return 0

.Lloop:
    LDR  x3, [x0], #8       // x3 = *array++
    ADD  x2, x2, x3         // sum += x3
    SUBS x1, x1, #1         // count--
    B.NE .Lloop

.Ldone:
    MOV  x0, x2             // return sum
    RET
```

## Inline Assembly in C (\_\_asm\_\_)

You can embed ARM64 assembly directly in C source:

```c
// Basic inline asm
__asm__("nop");

// With output and input operands
uint64_t count_zeros(uint64_t x) {
    uint64_t n;
    __asm__("clz %0, %1" : "=r"(n) : "r"(x));
    return n;
}

// Volatile inline asm (prevents optimization)
__asm__ volatile(
    "madd %[result], %[a], %[b], %[c]"
    : [result] "=r"(r)
    : [a] "r"(a), [b] "r"(b), [c] "r"(c)
);
```

### Constraint Letters

| Constraint | Meaning |
|-----------|---------|
| `r` | Any general-purpose register (x0–x30) |
| `w` | Any NEON/FP register |
| `=r` | Output to GP register |
| `+r` | Read/write GP register |
| `i` | Immediate integer |
| `m` | Memory operand |

## macOS System Calls

macOS uses BSD-style system calls. The syscall number goes in `x16`, arguments in `x0`–`x7`, and you use `SVC #0x80`:

```arm64
// write(1, buf, len) — syscall #4
MOV  x0, #1                // fd = STDOUT_FILENO
ADRP x1, message@PAGE
ADD  x1, x1, message@PAGEOFF  // buf = &message
MOV  x2, #13               // len = 13
MOV  x16, #4               // SYS_write
SVC  #0x80                 // syscall

// exit(0) — syscall #1
MOV  x0, #0               // exit code
MOV  x16, #1              // SYS_exit
SVC  #0x80
```

**Note:** Prefer calling `_exit`, `_puts`, `_write` etc. through libc instead of raw syscalls — the syscall numbers can change between macOS versions.

## Calling Convention Cheat Sheet

```
Before BL:
  x0–x7   ← Arguments (in order)
  x8      ← Indirect return buffer (if needed)
  v0–v7   ← FP/SIMD arguments

After BL:
  x0      → Return value (or x0+x1 for 128-bit)
  v0      → FP/SIMD return value
  x0–x15  → MAY BE CLOBBERED — save if you need them
  x19–x28 → PRESERVED (callee-saved)
  x29, x30 → PRESERVED
```

## Debugging Mixed C + Assembly with LLDB

Press **⌘⇧B** to compile with debug symbols and start an LLDB session. Useful commands:

```
(lldb) disassemble --name _fast_sum   // View disassembly of your function
(lldb) register read x0 x1 x2        // See register values
(lldb) memory read --size 8 --count 4 -- $x0  // Read 4 int64 from x0
(lldb) breakpoint set --name _fast_sum
(lldb) run
(lldb) next                           // Step over
(lldb) step                           // Step into
(lldb) register write x0 0x42        // Modify register
```

## Building and Linking on macOS

```bash
# Assemble + link ARM64 assembly
clang -arch arm64 my_func.s -o my_func

# Compile C with assembly together
clang -arch arm64 main.c my_asm.s -o my_program

# Build with debug info
clang -arch arm64 -g main.c my_asm.s -o my_program_debug

# View disassembly
otool -tv my_func
llvm-objdump -d --arch=arm64 my_func
```

## Object File Inspection

```bash
# Show Mach-O segments and sections
otool -l my_program | grep -A3 segname

# Show symbols
nm my_program | grep " T "    # Text (code) symbols

# Show shared library dependencies
otool -L my_program
```
