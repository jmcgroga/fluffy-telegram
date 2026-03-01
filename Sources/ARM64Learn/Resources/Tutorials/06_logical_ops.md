# Logical and Bitwise Operations

Logical operations manipulate individual bits of registers. They're fundamental for flags, masks, packing/unpacking fields, and many other operations.

## Basic Bitwise Instructions

```arm64
AND  x0, x1, x2        // x0 = x1 & x2   (bitwise AND)
ORR  x0, x1, x2        // x0 = x1 | x2   (bitwise OR)
EOR  x0, x1, x2        // x0 = x1 ^ x2   (bitwise XOR)
BIC  x0, x1, x2        // x0 = x1 & ~x2  (bit clear = AND NOT)
ORN  x0, x1, x2        // x0 = x1 | ~x2  (OR NOT)
EON  x0, x1, x2        // x0 = x1 ^ ~x2  (XOR NOT = XNOR)
MVN  x0, x1            // x0 = ~x1       (bitwise NOT = ORN x0, xzr, x1)
```

Add `S` to update NZCV flags: `ANDS`, `BICS`.

### TST — Test Bits Without Modifying

```arm64
TST  x0, x1            // ANDS xzr, x0, x1 — sets flags, discards result
TST  x0, #(1 << 7)     // Check if bit 7 is set
```

After `TST`, use `B.NE` to branch if any tested bit is set, `B.EQ` if all tested bits are 0.

## Bitmask Immediates

ARM64's logical instructions accept a special class of **bitmask immediates** — patterns that consist of a replicated sequence of 1s. This covers many common masks:

```arm64
AND x0, x0, #0xFF              // Keep only lower 8 bits
AND x0, x0, #0xFFFF            // Keep lower 16 bits
ORR x0, x0, #0xFF00            // Set bits 8–15
EOR x0, x0, #0x8000000000000000 // Toggle sign bit
```

## Shift Instructions

```arm64
LSL  x0, x1, #n        // Logical shift left n bits (multiply by 2^n)
LSR  x0, x1, #n        // Logical shift right n bits (unsigned divide by 2^n)
ASR  x0, x1, #n        // Arithmetic shift right n bits (signed divide, sign-extends)
ROR  x0, x1, #n        // Rotate right by n bits (circular shift)

// Register-specified shift amount:
LSL  x0, x1, x2        // Shift by amount in x2 (only lower 6 bits used)
```

| Instruction | Vacated bits filled with | Exits into |
|-------------|--------------------------|-----------|
| LSL | Zeros | C flag (last shifted out) |
| LSR | Zeros | C flag |
| ASR | Sign bit copies | C flag |
| ROR | Bits shifted out from right re-enter from left | C flag |

## Bit Field Operations

### Extract Bit Fields

```arm64
UBFX x0, x1, #lsb, #width    // x0 = unsigned bits [lsb+width-1 : lsb] of x1
SBFX x0, x1, #lsb, #width    // x0 = signed   bits [lsb+width-1 : lsb] of x1, sign-extended
```

**Example:** Extract a 4-bit nibble starting at bit 8:
```arm64
UBFX x0, x1, #8, #4          // x0 = (x1 >> 8) & 0xF
```

### Insert Bit Fields

```arm64
UBFIZ x0, x1, #lsb, #width   // x0[lsb+width-1:lsb] = zero-extended x1[width-1:0]
BFI   x0, x1, #lsb, #width   // x0[lsb+width-1:lsb] = x1[width-1:0]  (rest of x0 unchanged)
BFXIL x0, x1, #lsb, #width   // x0[width-1:0] = x1[lsb+width-1:lsb]
```

## Count Leading Zeros and Sign Bits

```arm64
CLZ  x0, x1            // Count leading zeros in x1 → x0
CLS  x0, x1            // Count leading sign bits (bits that match the sign bit)
RBIT x0, x1            // Reverse all 64 bits
REV  x0, x1            // Byte-reverse 64-bit word (little ↔ big endian)
REV16 x0, x1           // Byte-reverse each 16-bit halfword
REV32 x0, x1           // Byte-reverse each 32-bit word
```

## Common Bit Manipulation Patterns

```arm64
// Check if bit N is set (use TST + B.NE)
TST  x0, #(1 << N)     // Z=0 if bit N set; Z=1 if clear

// Set bit N
ORR  x0, x0, #(1 << N)

// Clear bit N
BIC  x0, x0, #(1 << N) // x0 = x0 & ~(1<<N)

// Toggle bit N
EOR  x0, x0, #(1 << N)

// Extract lower N bits (mask)
AND  x0, x0, #((1 << N) - 1)

// Round up to next multiple of 16
ADD  x0, x0, #15
BIC  x0, x0, #15        // x0 = (x0 + 15) & ~15

// Check if value is power of 2 (x0 > 0 assumed)
SUB  x1, x0, #1
ANDS xzr, x0, x1        // Z=1 if power of 2 (x0 & (x0-1) == 0)
```

## Logical vs. Arithmetic Shifts on Signed Values

```arm64
// ASR preserves sign, LSR does not
mov  x0, #-8            // x0 = 0xFFFFFFFFFFFFFFF8

asr  x1, x0, #1         // x1 = -4  (0xFFFFFFFFFFFFFFFC) — sign preserved
lsr  x2, x0, #1         // x2 = 0x7FFFFFFFFFFFFFFC — incorrect for signed /2!
```

Always use **ASR** when dividing signed integers by powers of 2.
