# ARM64 Registers

ARM64 provides **31 general-purpose registers** (`x0`–`x30`) plus several special registers. Understanding them is the foundation of ARM64 programming.

## 64-bit vs 32-bit Names

Every general-purpose register has two names:

```
 63                32 31               0
 ┌──────────────────┬──────────────────┐
 │   Upper 32 bits  │   w0 (32-bit)    │  ← x0 (64-bit view)
 └──────────────────┴──────────────────┘
```

- `x0` — access all 64 bits
- `w0` — access lower 32 bits only; **writing w0 zeroes the upper 32 bits**

Similarly for all registers: `x1`/`w1`, `x2`/`w2`, etc.

## Register Roles (AAPCS64 Calling Convention)

The ARM64 ABI (AAPCS64) defines how registers must be used at function boundaries:

| Registers | ABI Role | Caller/Callee Saved |
|-----------|---------|-------------------|
| x0–x7 | Arguments (1st–8th) and return values | Caller-saved |
| x8 | Indirect result location / macOS syscall # | Caller-saved |
| x9–x15 | Temporary (scratch) registers | Caller-saved |
| x16 (ip0) | Intra-procedure-call scratch | Caller-saved |
| x17 (ip1) | Intra-procedure-call scratch | Caller-saved |
| x18 | Platform register (reserved on macOS) | Do not use |
| x19–x28 | Callee-saved general registers | **Callee-saved** |
| x29 (fp) | Frame pointer | **Callee-saved** |
| x30 (lr) | Link register (return address) | **Callee-saved** |

**Caller-saved** = you must save these before calling a function if you still need them.
**Callee-saved** = a function *you write* must save and restore these before returning.

## Special Registers

### Stack Pointer (sp)
- Points to the top of the current stack frame
- **Must be 16-byte aligned** at the point of any `BL` instruction
- Cannot be used as a general-purpose register in most instructions

### Program Counter (pc)
- Address of the currently-executing instruction
- Cannot be directly written
- Used implicitly by branch instructions

### Zero Register (xzr / wzr)
- Always reads as zero regardless of what you write
- Useful for: `MOV x0, xzr` (zero a register), `STR xzr, [x1]` (zero memory)
- Synonym: `wzr` for the 32-bit form

### NZCV — Condition Flags Register

Set by instructions with the `S` suffix (`ADDS`, `SUBS`, `ANDS`, etc.) and by `CMP`/`CMN`/`TST`:

| Flag | Bit | Meaning |
|------|-----|---------|
| N | 31 | **Negative** — result had its sign bit set |
| Z | 30 | **Zero** — result was zero |
| C | 29 | **Carry** — unsigned overflow / borrow |
| V | 28 | **oVerflow** — signed overflow |

## Floating-Point / SIMD Registers

ARM64 has 32 additional registers (`v0`–`v31`) for floating-point and SIMD operations:

| Name | Width | Use |
|------|-------|-----|
| `b0` | 8-bit | Byte scalar |
| `h0` | 16-bit | Half-precision float |
| `s0` | 32-bit | Single-precision float |
| `d0` | 64-bit | Double-precision float |
| `q0` | 128-bit | NEON vector (16 bytes) |
| `v0.4s` | 128-bit | 4 × 32-bit float vector |

## Common Patterns

```arm64
// Zero a register
mov   x0, xzr          // x0 = 0
eor   x0, x0, x0       // x0 = x0 XOR x0 = 0

// Copy a register
mov   x1, x0           // x1 = x0

// 32-bit copy (upper bits zeroed)
mov   w2, w0           // x2 = zero-extend(w0)

// Compare to zero (doesn't modify register)
cbz   x0, label        // if x0 == 0, jump
cbnz  x0, label        // if x0 != 0, jump
```

## Register Viewer

Use the **Registers** tab in the memory panel on the right to see all registers and their current (simulated) values. Click on a value to toggle between hexadecimal and decimal display.
