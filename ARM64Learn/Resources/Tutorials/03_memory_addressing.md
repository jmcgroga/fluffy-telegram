# Memory Addressing Modes

ARM64 is a **load/store architecture**: all data processing operates on registers, and only `LDR`/`STR` (and their variants) access memory. This makes memory addressing modes critically important.

## Data Sizes

| Suffix | Bits | C type |
|--------|------|--------|
| `LDR x` | 64 | `uint64_t` / `int64_t` |
| `LDR w` | 32 | `uint32_t` / `int32_t` (zero-extended) |
| `LDRSW x` | 32→64 | `int32_t` (sign-extended to 64-bit) |
| `LDRH w` | 16 | `uint16_t` (zero-extended) |
| `LDRSH x` | 16→64 | `int16_t` (sign-extended) |
| `LDRB w` | 8 | `uint8_t` (zero-extended) |
| `LDRSB x` | 8→64 | `int8_t` (sign-extended) |

## Addressing Mode 1: Base Register

```arm64
LDR x0, [x1]          // Load 64-bit value at address stored in x1
STR x0, [x1]          // Store x0 to address stored in x1
LDRB w0, [x1]         // Load byte at address in x1, zero-extend to 32-bit
```

x1 is unchanged after the access.

## Addressing Mode 2: Base + Immediate Offset

```arm64
LDR x0, [x1, #8]      // Load from address (x1 + 8)
LDR x0, [x1, #-8]     // Negative offset
STR x0, [x1, #16]     // Store to (x1 + 16)
```

- Unsigned scaled offset: 0 to 4095 × data-size (e.g. 0–32760 for 64-bit)
- Unscaled (with `LDUR`/`STUR`): −256 to +255

## Addressing Mode 3: Pre-Index (Write-Back Before)

```arm64
LDR x0, [x1, #8]!     // x1 = x1 + 8; then load from new x1
STR x0, [x1, #-16]!   // x1 = x1 - 16; then store to new x1
```

The `!` ("bang") suffix means "write-back" — the base register is updated **before** the memory access. Used for `push` operations:

```arm64
STP x29, x30, [sp, #-16]!   // sp -= 16; mem[sp] = x29; mem[sp+8] = x30
```

## Addressing Mode 4: Post-Index (Write-Back After)

```arm64
LDR x0, [x1], #8      // Load from x1; then x1 = x1 + 8
STR x0, [x1], #16     // Store to x1; then x1 = x1 + 16
```

The base register is updated **after** the memory access. Used for `pop` operations and array iteration:

```arm64
LDP x29, x30, [sp], #16     // x29 = mem[sp]; x30 = mem[sp+8]; sp += 16
```

## Addressing Mode 5: Register Offset

```arm64
LDR x0, [x1, x2]          // Load from (x1 + x2)
LDR x0, [x1, x2, lsl #3]  // Load from (x1 + x2 * 8)  ← array indexing!
STR x0, [x1, w2, uxtw]    // Load from (x1 + zero-extend(w2))
```

The shift `lsl #3` multiplies the index by 8 (size of `uint64_t`), making this ideal for array indexing.

## PC-Relative Addressing (ADRP + ADD)

ARM64 uses a two-instruction sequence to load addresses of data. This is required because a single 32-bit instruction can't encode a full 64-bit address:

```arm64
ADRP x0, myData@PAGE       // x0 = page-aligned address of myData
ADD  x0, x0, myData@PAGEOFF // x0 = exact address of myData
```

`ADRP` loads a 4 KB-page-aligned address using a 21-bit PC-relative offset (±4 GB range).
`ADD` adds the page offset (lower 12 bits).

## Load/Store Pair (LDP / STP)

Load or store **two registers at once**. Essential for function prologues/epilogues:

```arm64
STP x0, x1, [x2]           // mem[x2] = x0; mem[x2+8] = x1
LDP x0, x1, [x2, #16]      // x0 = mem[x2+16]; x1 = mem[x2+24]
```

## Alignment Requirements

ARM64 requires **natural alignment** for loads and stores:
- 8-byte (`x` regs): address must be divisible by 8
- 4-byte (`w` regs): address must be divisible by 4
- 2-byte (`h` regs): address must be divisible by 2
- `sp` must be **16-byte aligned** at any function call

Misaligned access causes a Bus Error (SIGBUS) on Apple Silicon.

## The .data Section in Memory

Check the **Segments** tab in the memory panel to see how the `__DATA` segment maps your `.data` variables into the process address space.
