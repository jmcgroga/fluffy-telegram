# Stack and Functions

Understanding the stack and calling conventions is essential for writing correct assembly functions that interoperate with C and Swift.

## The AAPCS64 Calling Convention

The **ARM64 Application Binary Interface for Apple Platforms** (based on AAPCS64) defines the contract between callers and callees:

### Argument Passing

| Arguments | Location |
|-----------|----------|
| 1st–8th integer/pointer args | x0–x7 |
| 1st–8th FP/SIMD args | v0–v7 |
| 9th+ args (overflow) | Stack (caller pushes, right-to-left order) |
| Return value | x0 (or x0+x1 for 128-bit) |
| FP return value | v0 |
| Large struct returns | Indirect via x8 (pointer to space caller allocated) |

### Register Preservation

**Caller-saved** (callee may freely destroy):
- `x0–x18`, `v0–v7`, `v16–v31`

**Callee-saved** (callee must restore to original values):
- `x19–x28`, `x29` (fp), `x30` (lr)
- Lower 64 bits of `v8–v15` (upper bits are caller-saved)

## The Stack Frame

```
Higher addresses (previous sp)
┌────────────────────────────┐
│       Caller's frame       │
├────────────────────────────┤ ← sp at function entry (before prologue)
│  Saved x29 (frame pointer) │ ← [new_sp + 0]
│  Saved x30 (link register) │ ← [new_sp + 8]
├────────────────────────────┤ ← x29 (fp) set here by prologue
│  Saved x19                 │ ← [x29 + 16]  (if x19 used)
│  Saved x20                 │ ← [x29 + 24]  (if x20 used)
│  ...                       │
├────────────────────────────┤
│  Local variable 1          │ ← [x29 - 8]
│  Local variable 2          │ ← [x29 - 16]
│  ...                       │
└────────────────────────────┘ ← sp (after prologue)
Lower addresses
```

## Standard Prologue and Epilogue

```arm64
my_function:
    // === PROLOGUE ===
    STP  x29, x30, [sp, #-frameSize]!  // Allocate + save fp/lr
    MOV  x29, sp                        // Set frame pointer
    STP  x19, x20, [sp, #16]           // Save callee-saved regs (if used)

    // === BODY ===
    // ... use x0-x15 freely, use x19-x28 after saving ...

    // === EPILOGUE ===
    LDP  x19, x20, [sp, #16]           // Restore callee-saved regs
    LDP  x29, x30, [sp], #frameSize    // Restore fp/lr + deallocate
    RET                                 // Return to caller via x30
```

**Rule:** `frameSize` must be a **multiple of 16** to maintain 16-byte stack alignment.

## Leaf Functions (No Calls)

If a function doesn't call any other function, it doesn't need to save x30:

```arm64
fast_add:
    ADD  x0, x0, x1     // x0 = x0 + x1
    RET                  // No prologue/epilogue needed — saves time!
```

Leaf functions that use only caller-saved registers need no frame at all.

## Stack Alignment Rule

The ABI requires `sp` to be **16-byte aligned** at every `BL` instruction. Violating this causes `EXC_BAD_ACCESS` (SIGBUS) on Apple Silicon.

```arm64
// WRONG: sp is 8-byte misaligned!
SUB  sp, sp, #8
BL   some_function       // ← Crash!

// CORRECT: always adjust by multiples of 16
SUB  sp, sp, #16
BL   some_function       // ← OK
```

## Passing Arguments

```arm64
// C: long compute(long a, long b, long c, long d)
// ARM64: a→x0, b→x1, c→x2, d→x3; return in x0

compute:
    MUL  x4, x0, x1     // a * b
    ADD  x4, x4, x2     // (a*b) + c
    SUB  x0, x4, x3     // result = (a*b) + c - d
    RET
```

## Variadic Functions

For `printf`-style functions, named arguments go in registers as normal, overflow goes on stack. The `va_list` mechanism reads from the register save area then the stack.

## Recursive Functions

```arm64
// uint64_t factorial(uint64_t n)
factorial:
    STP  x29, x30, [sp, #-16]!    // Save frame
    MOV  x29, sp
    STP  x19, xzr, [sp, #-16]!   // Save n (x19 callee-saved)
    MOV  x19, x0

    CMP  x0, #1
    B.LS .Lbase                   // n <= 1: return 1

    SUB  x0, x19, #1              // arg = n - 1
    BL   factorial                // recursive call
    MUL  x0, x0, x19             // result = n * factorial(n-1)
    B    .Lexit

.Lbase:
    MOV  x0, #1                   // return 1

.Lexit:
    LDP  x19, xzr, [sp], #16
    LDP  x29, x30, [sp], #16
    RET
```

## Stack Panel

The **Stack** tab in the memory panel shows the ARM64 stack frame layout visually, including:
- The frame pointer chain
- Saved registers
- Local variable layout

Use the **Debug** button (⌘⇧B) to compile with symbols and explore the live stack in LLDB using `bt` (backtrace) and `frame variable`.
