# Introduction to ARM64 Assembly

ARM64 (also called AArch64) is the 64-bit instruction set architecture used by Apple Silicon Macs, iPhones, iPads, and many modern devices worldwide. Since Apple transitioned the Mac lineup to Apple Silicon in 2020, ARM64 assembly is now directly relevant for macOS development.

## Why Learn ARM64 Assembly?

Understanding assembly language makes you a better programmer at every level:

- **Performance** — Write hand-optimised routines that outperform the compiler for hot code paths
- **Debugging** — Read and understand disassembled code in LLDB or Instruments
- **Security** — Analyse binaries, understand vulnerabilities, and write safer code
- **Fundamentals** — Deep understanding of how the CPU executes your high-level code
- **Reverse engineering** — Analyse closed-source libraries and firmware

## RISC vs CISC

ARM64 is a **RISC** (Reduced Instruction Set Computer) architecture, which means:

- Instructions are **fixed 32 bits** wide (unlike x86's variable-length encoding)
- Only **LDR** and **STR** instructions access memory — everything else works on registers
- The CPU has **many registers** (31 general-purpose) to avoid memory access
- Simple, regular instruction format enables high clock speeds and energy efficiency

This contrasts with x86-64 (**CISC**), where instructions can directly operate on memory operands.

## Key Characteristics

| Feature | ARM64 (AArch64) |
|---------|----------------|
| Word size | 64-bit |
| Registers | 31 × 64-bit general-purpose |
| Instruction length | Fixed 32-bit |
| Endianness | Little-endian (default on Apple Silicon) |
| Memory model | Load/Store architecture |
| FP / SIMD | 32 × 128-bit NEON/FP registers |

## The Memory Panel

The panel on the right shows a typical ARM64 macOS process memory layout:

- **__TEXT** — Machine code and string literals (read + execute, never write)
- **__DATA** — Initialized and uninitialized global variables (read + write)
- **HEAP** — Dynamic allocations via `malloc`/`free` (grows upward)
- **STACK** — Function call frames and local variables (grows downward)

As you work through tutorials, the memory panel will highlight which segments are relevant to the current topic.

## Your First Program

The sample code shows the minimal ARM64 "Hello, World!" for macOS. It demonstrates:

1. The standard function **prologue** (`STP x29, x30, [sp, #-16]!`)
2. **PC-relative address loading** via `ADRP`/`ADD` (the ARM64 way to reference data)
3. Calling a C library function (`_puts`) with argument in `x0`
4. The standard function **epilogue** (`LDP x29, x30, [sp], #16` + `RET`)

## Naming Conventions on macOS

On macOS (Mach-O binary format), C function names are prefixed with an underscore in assembly:
- C: `puts(...)` → Assembly: `bl _puts`
- C: `int main()` → Assembly label: `_main:`

## Getting Started

Use the editor panel (middle) to modify and experiment with the code, then press **⌘B** to compile and run it. The build output appears in the bottom panel.

Continue to **Tutorial 2: Registers** to learn about all 31 general-purpose registers and their calling-convention roles.
