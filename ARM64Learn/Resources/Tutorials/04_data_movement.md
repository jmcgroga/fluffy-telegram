# Data Movement Instructions

Data movement is the most fundamental operation in assembly — moving values between registers, immediates, and memory.

## MOV — Move

```arm64
MOV x0, x1          // Register copy: x0 = x1
MOV w0, w1          // 32-bit copy: x0 = zero-extend(w1)
MOV x0, #42         // Immediate: x0 = 42
MOV x0, #-1         // Negative immediate: x0 = 0xFFFFFFFFFFFFFFFF
```

`MOV` is actually a pseudo-instruction. The assembler selects the best encoding:
- Register copy: uses `ORR xd, xzr, xm`
- Immediate: uses `MOVZ`, `MOVN`, or `ORR`/`AND` with bitmask immediate

## MVN — Move with NOT (Bitwise Complement)

```arm64
MVN x0, x1          // x0 = ~x1 (bitwise NOT)
MVN x0, x1, lsl #8  // x0 = ~(x1 << 8)
```

## Loading 64-bit Constants

Each ARM64 instruction is exactly 32 bits, so you can't encode a full 64-bit constant in one instruction. Use **MOVZ** + **MOVK**:

```arm64
MOVZ xd, #imm16           // xd = imm16 (zeroes remaining 48 bits)
MOVZ xd, #imm16, lsl #16  // xd = imm16 << 16
MOVZ xd, #imm16, lsl #32  // xd = imm16 << 32
MOVZ xd, #imm16, lsl #48  // xd = imm16 << 48

MOVK xd, #imm16           // Insert imm16 into bits[15:0], keep rest
MOVK xd, #imm16, lsl #16  // Insert imm16 into bits[31:16], keep rest
MOVK xd, #imm16, lsl #32  // Insert imm16 into bits[47:32], keep rest
MOVK xd, #imm16, lsl #48  // Insert imm16 into bits[63:48], keep rest
```

**Example:** Load `0xDEADBEEFCAFEBABE`

```arm64
movz x0, #0xBABE               // x0 = 0x000000000000BABE
movk x0, #0xCAFE, lsl #16      // x0 = 0x00000000CAFEBABE
movk x0, #0xBEEF, lsl #32      // x0 = 0x0000BEEFCAFEBABE
movk x0, #0xDEAD, lsl #48      // x0 = 0xDEADBEEFCAFEBABE
```

## LDR / STR — Load and Store

```arm64
// Load (memory → register)
LDR   x0, [x1]          // 64-bit load
LDR   w0, [x1]          // 32-bit load, zero-extended
LDRSW x0, [x1]          // 32-bit load, sign-extended to 64
LDRH  w0, [x1]          // 16-bit (halfword), zero-extended
LDRSH x0, [x1]          // 16-bit, sign-extended
LDRB  w0, [x1]          // 8-bit (byte), zero-extended
LDRSB x0, [x1]          // 8-bit, sign-extended

// Store (register → memory)
STR   x0, [x1]          // 64-bit store
STR   w0, [x1]          // 32-bit store
STRH  w0, [x1]          // 16-bit store
STRB  w0, [x1]          // 8-bit store
```

## LDP / STP — Load/Store Pair

Load or store **two** consecutive registers in a single instruction:

```arm64
LDP x0, x1, [x2]         // x0 = mem64[x2]; x1 = mem64[x2+8]
STP x0, x1, [x2]         // mem64[x2] = x0; mem64[x2+8] = x1

// Pre-index: decrement then store (push pair)
STP x29, x30, [sp, #-16]!  // sp -= 16; store pair at new sp

// Post-index: load then increment (pop pair)
LDP x29, x30, [sp], #16    // load pair from sp; sp += 16
```

## ADRP + ADD — Load Addresses

```arm64
ADRP x0, label@PAGE         // x0 = page address of label (pc-relative ±4GB)
ADD  x0, x0, label@PAGEOFF  // x0 = exact address of label
```

This two-instruction pattern is the standard way to reference data labels and global variables.

## Floating-Point Moves

```arm64
FMOV s0, w0           // Integer (w0) → float register (s0)
FMOV w0, s0           // Float register (s0) → integer (w0)
FMOV d0, x0           // 64-bit integer → double register
FMOV d0, #1.5         // Load FP immediate
```

## Memory Ordering and Atomics

For multi-threaded code, use **Load-Acquire** and **Store-Release**:

```arm64
LDAR  x0, [x1]         // Load-acquire: ordered with subsequent accesses
STLR  x0, [x1]         // Store-release: ordered with prior accesses
```

These prevent the CPU from reordering memory operations across the instruction.
