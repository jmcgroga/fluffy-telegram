import Foundation

// MARK: - Tutorial Loader

final class TutorialLoader {

    static func loadTutorials() -> [TutorialCategory] {
        return [
            TutorialCategory(
                name: "Getting Started",
                icon: "star",
                tutorials: [
                    loadTutorial(filename: "01_introduction",    fallback: t01),
                    loadTutorial(filename: "02_registers",       fallback: t02),
                    loadTutorial(filename: "03_memory_addressing", fallback: t03),
                ]
            ),
            TutorialCategory(
                name: "Instructions",
                icon: "cpu",
                tutorials: [
                    loadTutorial(filename: "04_data_movement",   fallback: t04),
                    loadTutorial(filename: "05_arithmetic",      fallback: t05),
                    loadTutorial(filename: "06_logical_ops",     fallback: t06),
                    loadTutorial(filename: "07_branches",        fallback: t07),
                ]
            ),
            TutorialCategory(
                name: "Advanced Topics",
                icon: "bolt",
                tutorials: [
                    loadTutorial(filename: "08_stack_functions", fallback: t08),
                    loadTutorial(filename: "09_simd_neon",       fallback: t09),
                    loadTutorial(filename: "10_interfacing_c",   fallback: t10),
                ]
            ),
        ]
    }

    // MARK: - Load from bundle resource

    private static func loadTutorial(filename: String, fallback: Tutorial) -> Tutorial {
        guard let url = Bundle.module.url(
            forResource: filename,
            withExtension: "md",
            subdirectory: "Resources/Tutorials"
        ) else {
            // Try alternate path
            if let url2 = Bundle.module.url(forResource: filename, withExtension: "md") {
                if let content = try? String(contentsOf: url2, encoding: .utf8) {
                    return Tutorial(
                        title: fallback.title,
                        subtitle: fallback.subtitle,
                        content: content,
                        sampleCode: fallback.sampleCode,
                        language: fallback.language,
                        memoryHighlights: fallback.memoryHighlights,
                        difficulty: fallback.difficulty
                    )
                }
            }
            return fallback
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return fallback
        }

        return Tutorial(
            title: fallback.title,
            subtitle: fallback.subtitle,
            content: content,
            sampleCode: fallback.sampleCode,
            language: fallback.language,
            memoryHighlights: fallback.memoryHighlights,
            difficulty: fallback.difficulty
        )
    }

    // MARK: - Inline Fallback Tutorials

    static let t01 = Tutorial(
        title: "Introduction to ARM64",
        subtitle: "AArch64 architecture overview",
        content: """
# Introduction to ARM64 Assembly

ARM64 (also called AArch64) is the 64-bit instruction set architecture used by Apple Silicon Macs, iPhones, and many modern devices.

## Why Learn ARM64 Assembly?

- **Performance**: Write hand-optimised routines that beat the compiler
- **Debugging**: Understand disassembled code in LLDB
- **Security**: Analyse binaries, understand exploits
- **Fundamentals**: Deep understanding of how software works

## Key Characteristics

| Feature | ARM64 |
|---------|-------|
| Word size | 64-bit |
| Registers | 31 × 64-bit general-purpose |
| Instruction length | Fixed 32-bit |
| Endianness | Little-endian (default) |
| Architecture | RISC (load/store) |

## ARM64 vs x86-64

ARM64 uses a **load/store** architecture: only `LDR`/`STR` instructions touch memory. All arithmetic operates on registers. This contrasts with x86-64 where most instructions can use memory operands directly.

## Your First Program

The sample code on the right shows a minimal ARM64 program. It calls `_puts` to print a string, then returns 0. Study the prologue/epilogue pattern — you'll use it in every function.

## Memory Layout

The memory panel on the right shows the four key segments of an ARM64 macOS binary:

- **__TEXT** — your code lives here (read + execute)
- **__DATA** — your `.data` and `.bss` variables
- **HEAP** — `malloc` allocations
- **STACK** — local variables and saved registers

## Next Steps

Continue to **Tutorial 2: Registers** to learn about the 31 general-purpose registers and their conventions.
""",
        sampleCode: ARM64Samples.helloWorld,
        language: .arm64,
        memoryHighlights: ["__TEXT", "__DATA"],
        difficulty: .beginner
    )

    static let t02 = Tutorial(
        title: "Registers",
        subtitle: "31 general-purpose + special registers",
        content: """
# ARM64 Registers

ARM64 provides **31 general-purpose registers** (`x0`–`x30`) plus several special registers.

## 64-bit vs 32-bit Names

Each register has two names:
- `x0` — accesses all 64 bits
- `w0` — accesses the lower 32 bits (upper 32 bits zeroed on write)

```
 63        32 31       0
 ┌──────────┬──────────┐
 │ upper 32 │  w0 / 32 │  ← x0
 └──────────┴──────────┘
```

## Register Conventions (AAPCS64)

| Register(s) | Role | Preserved? |
|-------------|------|-----------|
| x0–x7 | Arguments / return values | No (caller-saved) |
| x8 | Indirect result / syscall # | No |
| x9–x15 | Temporaries | No (caller-saved) |
| x16–x17 | Intra-call scratch (ip0/ip1) | No |
| x18 | Platform reserved | No |
| x19–x28 | Callee-saved | **Yes** |
| x29 (fp) | Frame pointer | **Yes** |
| x30 (lr) | Link register (return addr) | **Yes** |

## Special Registers

- **sp** — Stack pointer (must be 16-byte aligned at function calls)
- **pc** — Program counter (cannot be directly written)
- **xzr / wzr** — Zero register (reads always return 0)
- **nzcv** — Condition flags (N, Z, C, V)

## NZCV Flags

Set by instructions with the `S` suffix (e.g. `ADDS`, `SUBS`, `ANDS`):

| Flag | Meaning |
|------|---------|
| N | Negative — result was negative |
| Z | Zero — result was zero |
| C | Carry — unsigned overflow |
| V | Overflow — signed overflow |

## Example: Using Registers

See the code sample for common register operations.
""",
        sampleCode: """
// ARM64 Register Demonstration
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

    // Move with shift (MOVZ + MOVK for 64-bit constants)
    movz    x6, #0xBEEF              // x6 = 0x000000000000BEEF
    movk    x6, #0xDEAD, lsl #16    // x6 = 0x00000000DEADBEEF
    movk    x6, #0xCAFE, lsl #32    // x6 = 0x0000CAFEDEADBEEF
    movk    x6, #0xF00D, lsl #48    // x6 = 0xF00DCAFEDEADBEEF

    // xzr always reads as zero
    mov     x7, xzr          // x7 = 0

    // Return 0
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret
""",
        language: .arm64,
        memoryHighlights: ["STACK"],
        difficulty: .beginner
    )

    static let t03 = Tutorial(
        title: "Memory Addressing",
        subtitle: "Load/store addressing modes",
        content: """
# Memory Addressing Modes

ARM64 has several addressing modes for `LDR`/`STR` and their variants.

## Base Register

```
LDR x0, [x1]          // Load 8 bytes from address in x1
STR x0, [x1]          // Store x0 to address in x1
```

## Base + Immediate Offset

```
LDR x0, [x1, #8]      // Load from x1 + 8  (x1 unchanged)
LDR x0, [x1, #-8]     // Negative offset OK
```

Offset range: −256 to +255 (unscaled), or 0 to 32760 in multiples of data size.

## Pre-Index (update base before access)

```
LDR x0, [x1, #8]!     // x1 += 8, then load from new x1
STR x0, [x1, #-16]!   // x1 -= 16, then store to new x1
```

The `!` means "write-back" — base register is updated.

## Post-Index (update base after access)

```
LDR x0, [x1], #8      // Load from x1, then x1 += 8
STR x0, [x1], #16     // Store to x1, then x1 += 16
```

## Register Offset

```
LDR x0, [x1, x2]          // Load from x1 + x2
LDR x0, [x1, x2, lsl #3]  // Load from x1 + (x2 << 3)
```

## Literal (PC-relative)

```
LDR x0, =myLabel      // Load address of myLabel
LDR x0, myLabel       // Load 64-bit value AT myLabel
ADRP x0, myLabel@PAGE // Load page-aligned address
ADD  x0, x0, myLabel@PAGEOFF // Add page offset
```

## Load/Store Pair

```
LDP x0, x1, [sp, #16]     // Load two 8-byte values
STP x29, x30, [sp, #-16]! // Push two registers
```

`LDP`/`STP` are essential for the function prologue/epilogue pattern.

## Alignment Rules

- 8-byte values (`x` registers): must be 8-byte aligned
- 4-byte values (`w` registers): must be 4-byte aligned
- 16-byte aligned required for `sp` at function calls
""",
        sampleCode: """
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

    // --- Post-index: iterate with auto-advance ---
    adrp    x4, myArray@PAGE
    add     x4, x4, myArray@PAGEOFF
    ldr     x5, [x4], #8            // Load [0], x4 now points to [1]
    ldr     x6, [x4], #8            // Load [1], x4 now points to [2]

    // --- Register offset with shift ---
    adrp    x7, myArray@PAGE
    add     x7, x7, myArray@PAGEOFF
    mov     x8, #2                   // index = 2
    ldr     x9, [x7, x8, lsl #3]    // Load [2] = x7 + (2 * 8)

    // --- Store and load back ---
    str     x9, [x29, #16]           // Save to local variable on stack
    ldr     x10, [x29, #16]          // Load it back

    // Return sum in x0
    add     x0, x1, x2
    add     x0, x0, x3

    ldp     x29, x30, [sp], #48
    ret

.data
.align 3                            // 8-byte alignment for 64-bit data
myArray:
    .quad   10
    .quad   20
    .quad   30
""",
        language: .arm64,
        memoryHighlights: ["__DATA", "__TEXT"],
        difficulty: .beginner
    )

    static let t04 = Tutorial(
        title: "Data Movement",
        subtitle: "MOV, LDR, STR, LDP, STP",
        content: """
# Data Movement Instructions

## MOV — Move Immediate or Register

```arm64
MOV x0, #42          // x0 = 42
MOV x1, x0           // x1 = x0 (register copy)
MOV w2, w0           // 32-bit copy
MVN x3, x0           // x3 = ~x0 (bitwise NOT)
```

## Loading 64-bit Constants

Because each ARM64 instruction is only 32 bits wide, you can't encode a full 64-bit immediate directly. Use **MOVZ** + **MOVK**:

```arm64
MOVZ x0, #0xABCD              // x0 = 0x000000000000ABCD
MOVK x0, #0x1234, lsl #16     // x0 = 0x0000000012345678  wait, let me fix
MOVK x0, #0x5678, lsl #16     // x0 = 0x000000000000ABCD with bits[31:16] = 0x5678
```

MOVZ sets 16 bits and zeroes the rest. MOVK sets 16 bits leaving the rest unchanged.

## LDR / STR — Load and Store

```arm64
LDR x0, [x1]         // Load 64-bit value at address x1
LDRW w0, [x1]        // Load 32-bit value
LDRB w0, [x1]        // Load 8-bit (byte), zero-extend
LDRSB x0, [x1]       // Load 8-bit, sign-extend to 64-bit
LDRSH x0, [x1]       // Load 16-bit, sign-extend
LDRSW x0, [x1]       // Load 32-bit, sign-extend to 64-bit
```

## LDP / STP — Load/Store Pair

Load or store two registers simultaneously. Extremely common in prologues:

```arm64
// Prologue: push x29 and x30 (fp and lr)
STP x29, x30, [sp, #-16]!    // sp -= 16; mem[sp..sp+15] = {x29, x30}

// Epilogue: pop
LDP x29, x30, [sp], #16      // {x29, x30} = mem[sp..sp+15]; sp += 16
```

## ADRP / ADD — Load Address

```arm64
ADRP x0, label@PAGE          // x0 = page containing label
ADD  x0, x0, label@PAGEOFF   // x0 = exact address of label
```
""",
        sampleCode: """
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
    movk    x1, #0xF00D, lsl #48
    // x1 = 0xF00DCAFEDEADBEEF

    // --- Register copy ---
    mov     x2, x1               // 64-bit copy
    mov     w3, w1               // 32-bit copy: x3 = 0x00000000DEADBEEF

    // --- Load from memory ---
    adrp    x4, values@PAGE
    add     x4, x4, values@PAGEOFF

    ldr     x5, [x4]             // Load 64-bit
    ldr     w6, [x4, #8]         // Load 32-bit
    ldrb    w7, [x4, #12]        // Load byte, zero-extend

    // --- Store to stack locals ---
    str     x1, [x29, #16]       // Store x1 at sp+16
    ldr     x8, [x29, #16]       // Load it back

    mov     x0, #0
    ldp     x29, x30, [sp], #32
    ret

.data
.align 3
values:
    .quad   0xAABBCCDDEEFF0011    // 8 bytes at offset 0
    .word   0xDEADBEEF            // 4 bytes at offset 8
    .byte   0x42                  // 1 byte  at offset 12
""",
        language: .arm64,
        memoryHighlights: ["__DATA", "__TEXT", "STACK"],
        difficulty: .beginner
    )

    static let t05 = Tutorial(
        title: "Arithmetic",
        subtitle: "ADD, SUB, MUL, DIV and variants",
        content: """
# Arithmetic Instructions

## Addition and Subtraction

```arm64
ADD  x0, x1, x2        // x0 = x1 + x2
ADD  x0, x1, #42       // x0 = x1 + 42 (immediate)
ADDS x0, x1, x2        // x0 = x1 + x2, set NZCV flags
SUB  x0, x1, x2        // x0 = x1 - x2
SUBS x0, x1, x2        // x0 = x1 - x2, set flags
```

## Carry Operations

```arm64
ADC  x0, x1, x2        // x0 = x1 + x2 + C (add with carry)
SBC  x0, x1, x2        // x0 = x1 - x2 - ~C (subtract with borrow)
```

## Negation

```arm64
NEG  x0, x1            // x0 = -x1  (synonym for SUB x0, xzr, x1)
NEGS x0, x1            // x0 = -x1, set flags
```

## Multiplication

```arm64
MUL   x0, x1, x2       // x0 = x1 * x2 (lower 64 bits)
UMULH x0, x1, x2       // x0 = upper 64 bits of unsigned x1*x2
SMULH x0, x1, x2       // x0 = upper 64 bits of signed x1*x2
MADD  x0, x1, x2, x3   // x0 = x1*x2 + x3 (multiply-accumulate)
MSUB  x0, x1, x2, x3   // x0 = x3 - x1*x2
MNEG  x0, x1, x2       // x0 = -(x1*x2)
```

## Division

```arm64
UDIV  x0, x1, x2       // x0 = x1 / x2 (unsigned, truncates toward zero)
SDIV  x0, x1, x2       // x0 = x1 / x2 (signed)
```

Note: ARM64 has no hardware modulo instruction. Compute remainder as:
```arm64
UDIV x2, x0, x1        // x2 = x0 / x1
MSUB x3, x2, x1, x0    // x3 = x0 - x2*x1  (remainder)
```

## Shifts as Part of Instructions

ARM64 allows shift modifiers on the second operand:
```arm64
ADD x0, x1, x2, lsl #3   // x0 = x1 + (x2 << 3)
SUB x0, x1, x2, asr #2   // x0 = x1 - (x2 >> 2) arithmetic
```
""",
        sampleCode: """
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

    // Division with remainder
    udiv    x5, x0, x1          // x5 = 100 / 37 = 2 (integer)
    msub    x6, x5, x1, x0      // x6 = 100 - 2*37 = 26 (remainder)

    // Multiply-accumulate: x7 = x0*x1 + x2
    madd    x7, x0, x1, x2      // x7 = 100*37 + 137 = 3837

    // Shift in arithmetic operation
    mov     x8, #5
    add     x9, x0, x8, lsl #2  // x9 = 100 + (5 << 2) = 120

    // 128-bit multiply (get full product)
    mov     x10, #0xFFFFFFFFFFFF
    mov     x11, #0xFFFFFFFFFFFF
    mul     x12, x10, x11       // lower 64 bits of product
    umulh   x13, x10, x11       // upper 64 bits of product

    // Return the remainder (26)
    mov     x0, x6

    ldp     x29, x30, [sp], #16
    ret
""",
        language: .arm64,
        memoryHighlights: ["__TEXT", "STACK"],
        difficulty: .intermediate
    )

    static let t06 = Tutorial(
        title: "Logical Operations",
        subtitle: "AND, ORR, EOR, BIC, shifts",
        content: """
# Logical and Bitwise Operations

## Basic Bitwise

```arm64
AND  x0, x1, x2        // x0 = x1 & x2 (bitwise AND)
ORR  x0, x1, x2        // x0 = x1 | x2 (bitwise OR)
EOR  x0, x1, x2        // x0 = x1 ^ x2 (bitwise XOR)
BIC  x0, x1, x2        // x0 = x1 & ~x2 (bit clear / ANDN)
ORN  x0, x1, x2        // x0 = x1 | ~x2
EON  x0, x1, x2        // x0 = x1 ^ ~x2
MVN  x0, x1            // x0 = ~x1
```

Add `S` suffix to update flags: `ANDS`, `BICS`.

## Shifts and Rotates

```arm64
LSL  x0, x1, #n        // Logical shift left  (multiply by 2^n)
LSR  x0, x1, #n        // Logical shift right  (unsigned divide by 2^n)
ASR  x0, x1, #n        // Arithmetic shift right (signed divide, sign-extends)
ROR  x0, x1, #n        // Rotate right
```

Shift amount can be register: `LSL x0, x1, x2`

## Bit Field Operations

```arm64
UBFX x0, x1, #lsb, #width   // Extract unsigned bit field
SBFX x0, x1, #lsb, #width   // Extract signed bit field (sign-extends)
UBFIZ x0, x1, #lsb, #width  // Insert zero-extended field
BFI  x0, x1, #lsb, #width   // Bit field insert (x0[lsb+width-1:lsb] = x1[width-1:0])
```

## Count Leading Zeros

```arm64
CLZ  x0, x1            // Count leading zeros
CLS  x0, x1            // Count leading sign bits
```

## Common Patterns

```arm64
// Check if bit N is set
TST  x0, #(1 << N)     // Set Z=0 if bit N set, Z=1 if clear

// Mask to lower N bits
AND  x0, x0, #((1 << N) - 1)

// Set bit N
ORR  x0, x0, #(1 << N)

// Clear bit N
BIC  x0, x0, #(1 << N)

// Toggle bit N
EOR  x0, x0, #(1 << N)
```
""",
        sampleCode: """
// ARM64 Logical Operations
.global _main
.align  2
.text

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    mov     x0, #0b11001010    // x0 = 0xCA = 0b11001010
    mov     x1, #0b10110101    // x1 = 0xB5 = 0b10110101

    // Basic bitwise
    and     x2, x0, x1         // x2 = 0b10000000 = 0x80
    orr     x3, x0, x1         // x3 = 0b11111111 = 0xFF
    eor     x4, x0, x1         // x4 = 0b01111111 = 0x7F
    bic     x5, x0, x1         // x5 = 0b01001010 = 0x4A  (x0 & ~x1)
    mvn     x6, x0             // x6 = ~x0

    // Shifts
    lsl     x7, x0, #2         // x7 = x0 << 2 = 0x328
    lsr     x8, x0, #2         // x8 = x0 >> 2 = 0x32  (unsigned)
    mov     x9, #-40
    asr     x9, x9, #2         // Sign-extending: -40 >> 2 = -10

    // Bit field extract: get bits [5:2] of x0
    ubfx    x10, x0, #2, #4    // x10 = (x0 >> 2) & 0xF = 0b0010 = 2

    // Count leading zeros: CLZ of 0x80 = 56 (64-bit register)
    clz     x11, x2

    // TST: check if bit 7 of x0 is set
    tst     x0, #(1 << 7)      // Sets Z=0 (bit 7 IS set in 0xCA)
    // Use b.ne to branch if bit was set (Z=0 → NE)

    mov     x0, x3             // Return OR result (0xFF)
    ldp     x29, x30, [sp], #16
    ret
""",
        language: .arm64,
        memoryHighlights: ["__TEXT"],
        difficulty: .intermediate
    )

    static let t07 = Tutorial(
        title: "Branches & Control Flow",
        subtitle: "Conditional and unconditional branches",
        content: """
# Branches and Control Flow

## Unconditional Branches

```arm64
B   label           // Jump to label (PC-relative, ±128 MB)
BL  label           // Branch with Link: jump and save return addr to x30
BR  xN              // Branch to address in register
BLR xN              // Branch with Link to register
RET                 // Return: branch to address in x30 (LR)
RET xN              // Return to address in xN
```

## Conditional Branches

Condition codes are set by instructions ending in `S` (e.g. `CMP`, `ADDS`, `SUBS`):

```arm64
CMP x0, x1          // Sets flags from x0 - x1 (SUBS discards result)
B.EQ label          // Branch if Z=1  (equal)
B.NE label          // Branch if Z=0  (not equal)
B.LT label          // Branch if N≠V  (signed less than)
B.LE label          // Branch if Z=1 or N≠V
B.GT label          // Branch if Z=0 and N=V (signed greater than)
B.GE label          // Branch if N=V  (signed greater or equal)
B.LO label          // Branch if C=0  (unsigned lower)
B.LS label          // Branch if C=0 or Z=1
B.HI label          // Branch if C=1 and Z=0 (unsigned higher)
B.HS label          // Branch if C=1  (unsigned higher or same)
B.MI label          // Branch if N=1  (negative / minus)
B.PL label          // Branch if N=0  (positive or zero)
B.VS label          // Branch if V=1  (overflow)
B.VC label          // Branch if V=0  (no overflow)
```

## Compare and Branch (no flag register)

```arm64
CBZ  x0, label      // Branch if x0 == 0
CBNZ x0, label      // Branch if x0 != 0
TBZ  x0, #n, label  // Branch if bit n of x0 is 0
TBNZ x0, #n, label  // Branch if bit n of x0 is 1
```

## Conditional Select (branch-free)

```arm64
CSEL x0, x1, x2, cond  // x0 = (cond) ? x1 : x2
CSET x0, cond           // x0 = (cond) ? 1 : 0
CSINC x0, x1, x2, cond // x0 = (cond) ? x1 : x2+1
```

## Loop Pattern

```arm64
    mov     x0, #0          // counter = 0
    mov     x1, #10         // limit = 10
loop:
    // ... loop body ...
    add     x0, x0, #1      // counter++
    cmp     x0, x1
    b.lt    loop             // if counter < limit, repeat
```
""",
        sampleCode: """
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
    b       .Lend_if
.Lbig:
    mov     x1, #2
.Lend_if:
    // x1 = 1 (since 42 < 50)

    // --- loop: sum 1..10 ---
    mov     x2, #0          // sum = 0
    mov     x3, #1          // i = 1
    mov     x4, #10         // limit
.Lloop:
    add     x2, x2, x3      // sum += i
    add     x3, x3, #1      // i++
    cmp     x3, x4
    b.le    .Lloop           // while i <= 10
    // x2 = 55

    // --- CBZ/CBNZ ---
    mov     x5, #0
    cbz     x5, .Lwas_zero  // Branch because x5 == 0
    mov     x6, #100
    b       .Lafter_zero
.Lwas_zero:
    mov     x6, #200
.Lafter_zero:

    // --- CSEL (branch-free conditional) ---
    mov     x7, #10
    mov     x8, #20
    cmp     x2, #55         // x2 should be 55
    csel    x9, x7, x8, eq  // x9 = (x2 == 55) ? x7 : x8 = 10

    mov     x0, x2          // return sum (55)
    ldp     x29, x30, [sp], #16
    ret
""",
        language: .arm64,
        memoryHighlights: ["__TEXT"],
        difficulty: .intermediate
    )

    static let t08 = Tutorial(
        title: "Stack & Functions",
        subtitle: "ABI, calling convention, prologues",
        content: """
# Stack and Functions

## AAPCS64 Calling Convention

The **ARM64 Application Binary Interface** defines:

### Passing Arguments
- Up to 8 integer/pointer args passed in **x0–x7**
- Up to 8 floating-point args in **v0–v7**
- Additional args passed on the **stack** (right to left)
- Return value in **x0** (or **x0/x1** for 128-bit)

### Preserved Registers (callee must save/restore)
- **x19–x28**, **x29 (fp)**, **x30 (lr)**
- If you use these, push them at function entry and pop before returning

### Caller-Saved Registers (may be clobbered by callees)
- **x0–x15** — assume these are destroyed after a function call

## Stack Frame Layout

```
Higher addresses
┌─────────────────┐ ← previous sp
│ caller's frame  │
│─────────────────│ ← sp before prologue
│ saved x30 (lr)  │ ← [x29, #8]
│ saved x29 (fp)  │ ← [x29] / [sp]
│─────────────────│ ← x29 (fp) points here
│ saved x19–x28   │   (if used)
│─────────────────│
│ local variables │
│─────────────────│ ← sp (after prologue)
Lower addresses
```

## Standard Prologue / Epilogue

```arm64
my_function:
    // Prologue
    stp     x29, x30, [sp, #-48]!  // Allocate frame, save fp/lr
    mov     x29, sp                  // Set frame pointer
    stp     x19, x20, [sp, #16]     // Save callee-saved regs if used

    // ... function body ...

    // Epilogue
    ldp     x19, x20, [sp, #16]     // Restore callee-saved regs
    ldp     x29, x30, [sp], #48     // Restore fp/lr, deallocate frame
    ret
```

## Stack Alignment

The stack pointer must be **16-byte aligned** at every `BL` instruction (function call). Most macOS function calls will crash with a bus error on misaligned stacks.

## Variadic Functions

For functions with `...` (varargs), additional arguments are accessed via `va_list`. In ARM64 ABI, the named arguments come in registers, and further args spill to stack.
""",
        sampleCode: """
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

// uint64_t fibonacci(uint64_t n)
// Uses callee-saved x19 and x20
fibonacci:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]  // Save callee-saved registers

    mov     x19, x0              // x19 = n (preserved across calls)

    cmp     x0, #1
    b.le    .Lfib_base           // if n <= 1, return n

    sub     x0, x19, #1          // arg = n - 1
    bl      fibonacci            // recursive call
    mov     x20, x0              // x20 = fib(n-1)  [callee-saved, so it's safe]

    sub     x0, x19, #2          // arg = n - 2
    bl      fibonacci            // recursive call
    add     x0, x0, x20          // fib(n) = fib(n-1) + fib(n-2)
    b       .Lfib_exit

.Lfib_base:
    // n <= 1: return n unchanged (already in x0)
.Lfib_exit:
    ldp     x19, x20, [sp, #16]  // Restore callee-saved registers
    ldp     x29, x30, [sp], #32
    ret

// main
_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Call add_three(10, 20, 12)
    mov     w0, #10
    mov     w1, #20
    mov     w2, #12
    bl      add_three           // returns 42

    // Call fibonacci(10) → 55
    mov     x0, #10
    bl      fibonacci           // x0 = 55

    ldp     x29, x30, [sp], #16
    ret
""",
        language: .arm64,
        memoryHighlights: ["STACK", "__TEXT"],
        difficulty: .intermediate
    )

    static let t09 = Tutorial(
        title: "SIMD / NEON",
        subtitle: "Vector registers and operations",
        content: """
# SIMD and NEON

ARM64's SIMD (Single Instruction, Multiple Data) unit is called **NEON** (or Advanced SIMD). It operates on **128-bit vector registers** (`v0`–`v31`).

## Vector Register Layouts

Each `v` register can be viewed as different lane arrangements:

| Suffix | Type | Lanes | Total bits |
|--------|------|-------|-----------|
| `.16b` | 8-bit bytes | 16 | 128 |
| `.8h` | 16-bit halfwords | 8 | 128 |
| `.4s` | 32-bit words | 4 | 128 |
| `.2d` | 64-bit doublewords | 2 | 128 |

## Load / Store Vectors

```arm64
LD1 {v0.16b}, [x0]           // Load 16 bytes into v0
LD1 {v0.4s, v1.4s}, [x0]    // Load 8 words into v0 and v1
ST1 {v0.16b}, [x0]           // Store 16 bytes from v0
```

## Arithmetic on Vectors

```arm64
ADD  v0.4s, v1.4s, v2.4s    // 4 × (32-bit add)
SUB  v0.8h, v1.8h, v2.8h    // 8 × (16-bit subtract)
MUL  v0.4s, v1.4s, v2.4s    // 4 × (32-bit multiply)
```

## Scalar Operations on FP Regs

The `s` and `d` aliases access lower portions:
- `s0` — lower 32 bits of `v0` (single-precision float)
- `d0` — lower 64 bits of `v0` (double-precision float)

```arm64
FADD d0, d1, d2             // d0 = d1 + d2 (double)
FMUL s0, s1, s2             // s0 = s1 * s2 (single)
FSQRT d0, d1                // d0 = sqrt(d1)
FCVT d0, s0                 // Convert single → double
```

## Use Case: SIMD Sum of 4 Integers

```arm64
    LD1   {v0.4s}, [x0]       // Load 4 int32 values
    ADDV  s1, v0.4s           // s1 = sum of all 4 lanes
    MOV   w0, v1.s[0]         // Move result to GP register
```

## Why SIMD Matters

On Apple Silicon, SIMD can process 4–16 values per clock cycle versus 1. Image processing, DSP, machine learning, and string operations all benefit enormously from NEON.
""",
        sampleCode: """
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

    // Load 4 × float32 into v0 and v1
    ld1     {v0.4s}, [x0]      // v0 = {a[0], a[1], a[2], a[3]}
    ld1     {v1.4s}, [x1]      // v1 = {b[0], b[1], b[2], b[3]}

    // Element-wise multiply
    fmul    v2.4s, v0.4s, v1.4s // v2 = {a0*b0, a1*b1, a2*b2, a3*b3}

    // Sum all 4 lanes → scalar
    faddp   v3.4s, v2.4s, v2.4s // pairwise add: {a0b0+a1b1, a2b2+a3b3, ...}
    faddp   s4, v3.2s            // s4 = final dot product (scalar)

    // Move float result to integer register for return
    fmov    w0, s4               // Convert float bits to int (for demo)

    ldp     x29, x30, [sp], #16
    ret

// float arrays (IEEE 754 single precision)
.data
.align 2
vec_a:
    .single  1.0, 2.0, 3.0, 4.0     // {1, 2, 3, 4}
vec_b:
    .single  2.0, 3.0, 4.0, 5.0     // {2, 3, 4, 5}
// Dot product = 1*2 + 2*3 + 3*4 + 4*5 = 2+6+12+20 = 40
""",
        language: .arm64,
        memoryHighlights: ["__DATA", "__TEXT"],
        difficulty: .advanced
    )

    static let t10 = Tutorial(
        title: "Interfacing with C",
        subtitle: "Calling C from assembly and vice versa",
        content: """
# Interfacing with C

## Calling C Functions from Assembly

Any C function can be called from assembly by:
1. Putting arguments in `x0`–`x7` (per AAPCS64)
2. Using `BL function_name` (prefixed with `_` on macOS)
3. Reading return value from `x0`

```arm64
// Call printf("Value: %d\\n", 42)
adrp  x0, fmt@PAGE
add   x0, x0, fmt@PAGEOFF   // x0 = format string
mov   w1, #42               // x1 = integer argument
bl    _printf               // call printf

.data
fmt: .asciz "Value: %d\\n"
```

## System Calls (macOS/XNU)

On macOS, system calls use the `SVC #0x80` instruction. The syscall number goes in **x16**:

```arm64
// write(1, buf, len)
mov x0, #1          // fd = stdout
adrp x1, msg@PAGE
add  x1, x1, msg@PAGEOFF   // buf
mov x2, #13         // len
mov x16, #4         // SYS_write = 4
svc #0x80

// exit(0)
mov x0, #0          // exit code
mov x16, #1         // SYS_exit = 1
svc #0x80
```

## Calling Assembly from C

Declare external function in C:
```c
extern int64_t my_asm_func(int64_t a, int64_t b);
```

In assembly:
```arm64
.global _my_asm_func   // Must have underscore prefix on macOS
_my_asm_func:
    add x0, x0, x1     // return a + b
    ret
```

## Mixed C + Assembly Example

The sample code shows a complete C program that calls an assembly function, demonstrating how the two languages interoperate seamlessly through the ABI.

## Important macOS Notes

- Functions must be prefixed with `_` in assembly (C compiler adds this automatically)
- `objc_msgSend` follows the same ABI
- Swift functions on arm64 follow the same calling convention
- Use `__asm__` in C for inline assembly
""",
        sampleCode: """
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

static inline uint64_t count_leading_zeros(uint64_t x) {
    uint64_t n;
    __asm__ volatile ("clz %0, %1" : "=r"(n) : "r"(x));
    return n;
}

static inline uint64_t rotate_right(uint64_t x, int bits) {
    uint64_t result;
    __asm__ volatile ("ror %0, %1, %2" : "=r"(result) : "r"(x), "r"((uint64_t)bits));
    return result;
}

int main(void) {
    // Call assembly multiply-add
    int64_t r = arm64_multiply_add(6, 7, 10);  // 6*7+10 = 52
    printf("MADD(6, 7, 10)  = %lld\\n", r);

    // Count leading zeros
    uint64_t val = 0x0000FFFF00000001ULL;
    uint64_t lz = count_leading_zeros(val);
    printf("CLZ(0x0000FFFF00000001) = %llu\\n", lz);

    // Rotate right
    uint64_t rotated = rotate_right(0xDEADBEEFCAFEBABE, 16);
    printf("ROR(0xDEADBEEFCAFEBABE, 16) = 0x%016llX\\n", rotated);

    return 0;
}
""",
        language: .c,
        memoryHighlights: ["__TEXT", "__DATA", "STACK"],
        difficulty: .advanced
    )
}
