# Branches and Control Flow

Branching instructions control the flow of execution. ARM64 has a rich set of branch instructions covering unconditional jumps, function calls, conditional branches, and branch-free conditionals.

## Unconditional Branches

```arm64
B   label              // Jump to label (PC-relative, ±128 MB range)
BL  label              // Branch with Link: jump to label, save return addr in x30
BR  xN                 // Branch to address in register xN
BLR xN                 // Branch with Link to register: jump + save return in x30
RET                    // Return: branch to address in x30 (link register)
RET xN                 // Return to address in xN (unusual)
```

`BL` sets `x30 = pc + 4` (address of next instruction), then jumps to `label`.
`RET` is equivalent to `BR x30` but hints to the CPU this is a function return (enables return prediction).

## Condition Codes (NZCV)

Condition codes are set by instructions ending in `S` (e.g. `ADDS`, `SUBS`, `ANDS`) and by comparison instructions:

```arm64
CMP  x0, x1           // x0 - x1 (sets flags, discards result)
CMP  x0, #42          // x0 - 42
CMN  x0, x1           // x0 + x1 (compare negative)
TST  x0, x1           // x0 & x1 (test bits)
```

## Conditional Branch Mnemonics

| Mnemonic | Condition | Flags |
|----------|-----------|-------|
| `B.EQ` | Equal | Z=1 |
| `B.NE` | Not equal | Z=0 |
| `B.LT` | Signed less than | N≠V |
| `B.LE` | Signed less or equal | Z=1 or N≠V |
| `B.GT` | Signed greater than | Z=0 and N=V |
| `B.GE` | Signed greater or equal | N=V |
| `B.LO` | Unsigned lower (below) | C=0 |
| `B.LS` | Unsigned lower or same | C=0 or Z=1 |
| `B.HI` | Unsigned higher (above) | C=1 and Z=0 |
| `B.HS` | Unsigned higher or same | C=1 |
| `B.MI` | Minus (negative) | N=1 |
| `B.PL` | Plus (positive or zero) | N=0 |
| `B.VS` | Overflow | V=1 |
| `B.VC` | No overflow | V=0 |
| `B.AL` | Always (unconditional) | — |

**Signed vs Unsigned:** Use `LT/LE/GT/GE` for signed comparisons, `LO/LS/HI/HS` for unsigned.

## Compare and Branch (No Flag Register Access)

These are efficient single-instruction tests that avoid setting the flags register:

```arm64
CBZ  x0, label        // Branch to label if x0 == 0
CBNZ x0, label        // Branch to label if x0 != 0
TBZ  x0, #n, label    // Branch if bit n of x0 is 0
TBNZ x0, #n, label    // Branch if bit n of x0 is 1
```

`CBZ`/`CBNZ` have ±1 MB range; `TBZ`/`TBNZ` have ±32 KB range.

## Conditional Select (Branch-Free)

Avoid branch misprediction penalties with conditional select instructions:

```arm64
CSEL  x0, x1, x2, cond   // x0 = (cond) ? x1 : x2
CSINC x0, x1, x2, cond   // x0 = (cond) ? x1 : x2 + 1
CSINV x0, x1, x2, cond   // x0 = (cond) ? x1 : ~x2
CSNEG x0, x1, x2, cond   // x0 = (cond) ? x1 : -x2
CSET  x0, cond            // x0 = (cond) ? 1 : 0  (CSINC x0, xzr, xzr, !cond)
CSETM x0, cond            // x0 = (cond) ? -1 : 0
CINC  x0, x1, cond        // x0 = (cond) ? x1+1 : x1
CINV  x0, x1, cond        // x0 = (cond) ? ~x1  : x1
CNEG  x0, x1, cond        // x0 = (cond) ? -x1  : x1
```

**Example:** `int abs(int x)` branch-free:
```arm64
CMP  w0, #0
CNEG w0, w0, lt           // if x < 0, negate it
RET
```

## Control Flow Patterns

### if/else

```arm64
    CMP  x0, #10
    B.LT .Lelse            // if x0 >= 10, skip then-branch
    // then-block
    MOV  x1, #1
    B    .Lend_if
.Lelse:
    // else-block
    MOV  x1, #2
.Lend_if:
```

### for loop (count-down)

```arm64
    MOV  x0, #10           // n = 10
.Lloop:
    // ... loop body using x0 as counter ...
    SUBS x0, x0, #1        // n-- (sets Z flag when n reaches 0)
    B.NE .Lloop             // loop while n != 0
```

Count-down loops (`SUBS` + `B.NE`) are efficient because `SUBS` sets the Z flag directly.

### while loop

```arm64
    B    .Lcheck           // jump to check first (do-while uses a different structure)
.Lloop:
    // loop body
.Lcheck:
    CMP  x0, x1
    B.LT .Lloop
```

### Switch/Jump Table

```arm64
    CMP  x0, #MAX_CASE
    B.HS .Ldefault         // Bounds check

    ADR  x1, .Ljumptable
    LDR  x2, [x1, x0, lsl #3]   // Load function pointer (8 bytes each)
    BR   x2

.Ljumptable:
    .quad .Lcase0
    .quad .Lcase1
    .quad .Lcase2
```

## Tail Call Optimization

When the last thing a function does is call another and return its result, replace `BL` + `RET` with `B`:

```arm64
// Instead of:
    BL   other_function
    RET

// Use tail call:
    B    other_function    // Jumps, uses our x30 → other_function returns directly to our caller
```

This avoids creating a new stack frame and is a major performance optimization in recursive code.
