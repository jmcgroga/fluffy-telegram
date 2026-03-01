# Arithmetic Instructions

ARM64 provides a rich set of arithmetic instructions. A key design principle: all arithmetic operates on **registers only** — never directly on memory.

## Addition

```arm64
ADD  x0, x1, x2           // x0 = x1 + x2
ADD  x0, x1, #imm         // x0 = x1 + immediate (0–4095, optionally << 12)
ADDS x0, x1, x2           // x0 = x1 + x2, update NZCV flags
ADD  x0, x1, x2, lsl #2   // x0 = x1 + (x2 << 2) = x1 + x2*4
ADD  x0, x1, x2, sxtw     // x0 = x1 + sign-extend(w2) to 64-bit
```

## Subtraction

```arm64
SUB  x0, x1, x2           // x0 = x1 - x2
SUBS x0, x1, x2           // x0 = x1 - x2, update NZCV flags
CMP  x0, x1               // SUBS xzr, x0, x1 — sets flags, discards result
CMN  x0, x1               // ADDS xzr, x0, x1 — "compare negative"
NEG  x0, x1               // x0 = -x1  (SUB x0, xzr, x1)
NEGS x0, x1               // x0 = -x1, update flags
```

## Carry / Borrow Arithmetic

For extended-precision (multi-word) arithmetic:

```arm64
ADC  x0, x1, x2           // x0 = x1 + x2 + C  (Add with Carry)
ADCS x0, x1, x2           // ADC + set flags
SBC  x0, x1, x2           // x0 = x1 - x2 - ~C (Subtract with Borrow)
SBCS x0, x1, x2           // SBC + set flags
```

**128-bit add example:**
```arm64
// (x1:x0) + (x3:x2)  →  (x1:x0)
ADDS x0, x0, x2           // Add low 64 bits, C set on overflow
ADC  x1, x1, x3           // Add high 64 bits + carry
```

## Multiplication

```arm64
MUL   x0, x1, x2          // x0 = x1 * x2  (lower 64 bits of 128-bit product)
UMULH x0, x1, x2          // x0 = upper 64 bits of unsigned x1 * x2
SMULH x0, x1, x2          // x0 = upper 64 bits of signed x1 * x2

// Multiply-accumulate (very common in DSP / linear algebra)
MADD  x0, x1, x2, x3      // x0 = x1*x2 + x3
MSUB  x0, x1, x2, x3      // x0 = x3 - x1*x2
MNEG  x0, x1, x2           // x0 = -(x1*x2)  (MSUB x0, x1, x2, xzr)

// 64×64 → 128 bit full product
MUL   x4, x0, x1           // x4 = lower 64 bits
UMULH x5, x0, x1           // x5 = upper 64 bits
// Result in x5:x4
```

## Division

```arm64
UDIV x0, x1, x2           // x0 = x1 / x2  (unsigned integer division)
SDIV x0, x1, x2           // x0 = x1 / x2  (signed, truncates toward zero)
```

**ARM64 has no hardware MOD instruction.** Compute remainder with:
```arm64
UDIV x2, x0, x1           // x2 = x0 / x1
MSUB x3, x2, x1, x0       // x3 = x0 - x2*x1  ← remainder
```

## Floating-Point Arithmetic

```arm64
FADD  d0, d1, d2           // d0 = d1 + d2  (double)
FSUB  s0, s1, s2           // s0 = s1 - s2  (single)
FMUL  d0, d1, d2           // d0 = d1 * d2
FDIV  d0, d1, d2           // d0 = d1 / d2
FSQRT d0, d1               // d0 = sqrt(d1)
FNEG  d0, d1               // d0 = -d1
FABS  d0, d1               // d0 = |d1|

// Fused multiply-add (single rounding, more accurate)
FMADD d0, d1, d2, d3       // d0 = d1*d2 + d3
FMSUB d0, d1, d2, d3       // d0 = d3 - d1*d2
```

## Shift as Arithmetic Modifier

ARM64 instructions can incorporate a shift on the last register operand **for free** (no extra instruction cost):

```arm64
ADD x0, x1, x2, lsl #3    // x0 = x1 + (x2 * 8) — array element pointer
SUB x0, x1, x2, asr #2    // x0 = x1 - (x2 >> 2) — arithmetic right shift
```

Available shifts: `lsl` (logical left), `lsr` (logical right), `asr` (arithmetic right)

## Integer ↔ Float Conversion

```arm64
SCVTF d0, x0              // Signed int64 → double
UCVTF d0, x0              // Unsigned int64 → double
SCVTF s0, w0              // Signed int32 → single
FCVTZS x0, d0             // double → int64, truncate toward zero (signed)
FCVTZU x0, d0             // double → uint64, truncate toward zero (unsigned)
FCVT d0, s0               // single → double (widen)
FCVT s0, d0               // double → single (narrow, may lose precision)
```

## Worked Example: Euclidean GCD

```arm64
// gcd(a, b): a in x0, b in x1
gcd:
    cbz  x1, gcd_done     // if b == 0, return a
    udiv x2, x0, x1       // x2 = a / b
    msub x0, x2, x1, x0   // x0 = a mod b
    mov  x2, x0            // swap a and b
    mov  x0, x1
    mov  x1, x2
    b    gcd               // tail call
gcd_done:
    ret                    // return a (in x0)
```

Note the **tail call** optimization: `B` instead of `BL` + `RET` when the last thing a function does is call another function with the same return point.
