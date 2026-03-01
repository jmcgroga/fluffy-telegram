# SIMD and NEON

ARM64's **Advanced SIMD** extension (marketed as NEON) provides 32 × 128-bit vector registers for processing multiple data elements simultaneously. Apple Silicon chips have particularly powerful NEON implementations.

## Vector Register Naming

Each `v` register is 128 bits and can be viewed through different "lenses":

```
v0 (128 bits)
┌───────────────────────────────────────┐
│ b15│b14│b13│ ... │b1 │b0             │  v0.16b  (16 × uint8)
│ h7 │ h6 │ h5 │ ... │h1 │h0          │  v0.8h   (8  × uint16)
│    s3   │   s2   │   s1   │   s0    │  v0.4s   (4  × uint32 / float)
│           d1            │    d0     │  v0.2d   (2  × uint64 / double)
└───────────────────────────────────────┘
q0 (all 128 bits as one unit)
```

Scalar aliases (lower portion only):
- `b0` — byte (bit 0)
- `h0` — halfword (bits 15:0)
- `s0` — singleword / float (bits 31:0)
- `d0` — doubleword / double (bits 63:0)

## Load and Store Vectors

```arm64
// Load into one vector register
LD1  {v0.16b}, [x0]           // 16 bytes from [x0] → v0

// Load into multiple consecutive registers (interleaved structures)
LD1  {v0.4s, v1.4s}, [x0]     // 32 bytes → v0, v1 (sequential)
LD2  {v0.4s, v1.4s}, [x0]     // Deinterleave: even→v0, odd→v1
LD3  {v0.8b, v1.8b, v2.8b}, [x0]  // 3-channel interleaved

// With post-index increment
LD1  {v0.16b}, [x0], #16      // Load 16 bytes, x0 += 16

// Store
ST1  {v0.16b}, [x0]           // Store v0 to [x0]
ST2  {v0.8h, v1.8h}, [x0]     // Interleave and store
```

## Arithmetic Operations

```arm64
// Integer SIMD
ADD  v0.4s,  v1.4s,  v2.4s   // 4 × 32-bit adds
SUB  v0.8h,  v1.8h,  v2.8h   // 8 × 16-bit subtracts
MUL  v0.4s,  v1.4s,  v2.4s   // 4 × 32-bit multiplies
MLA  v0.4s,  v1.4s,  v2.4s   // v0 += v1 * v2 (multiply-accumulate)

// Unsigned saturation (clamps at 0xFF for bytes, etc.)
UQADD  v0.8b, v1.8b, v2.8b   // Saturating add
UQSUB  v0.8b, v1.8b, v2.8b   // Saturating subtract

// Pairwise
ADDP  v0.4s, v1.4s, v2.4s    // Pairwise add: {v1[0]+v1[1], v1[2]+v1[3], v2[0]+v2[1], ...}
FADDP v0.2d, v1.2d, v2.2d    // Floating-point pairwise add

// Horizontal
ADDV  s0, v1.4s               // Sum all 4 floats → s0
UMAXV b0, v1.16b              // Max of 16 bytes → b0
UMINV b0, v1.16b              // Min of 16 bytes → b0
```

## Floating-Point SIMD

```arm64
// Vector float operations
FADD  v0.4s, v1.4s, v2.4s    // 4 × float32 add
FSUB  v0.2d, v1.2d, v2.2d    // 2 × float64 subtract
FMUL  v0.4s, v1.4s, v2.4s    // 4 × float32 multiply
FDIV  v0.4s, v1.4s, v2.4s    // 4 × float32 divide
FSQRT v0.4s, v1.4s            // 4 × square root
FABS  v0.4s, v1.4s            // 4 × absolute value
FNEG  v0.4s, v1.4s            // 4 × negate

// Fused multiply-add
FMLA  v0.4s, v1.4s, v2.4s    // v0 += v1 * v2 (single rounding, accurate)
FMLS  v0.4s, v1.4s, v2.4s    // v0 -= v1 * v2

// Scalar by lane
FMUL  v0.4s, v1.4s, v2.s[0]  // Multiply each of v1 by v2's first lane
```

## Element Manipulation

```arm64
// Duplicate (splat) a scalar to all lanes
DUP  v0.4s, w0                // All 4 lanes = w0
DUP  v0.4s, v1.s[2]           // All 4 lanes = v1 lane 2

// Insert/Extract
INS  v0.s[1], w0              // Set lane 1 of v0 to w0
MOV  w0, v0.s[1]              // Move lane 1 of v0 to w0 (integer)
UMOV w0, v0.b[3]              // Extract byte lane 3 (unsigned)
SMOV x0, v0.b[3]              // Extract byte lane 3 (sign-extended)

// Permute
EXT  v0.16b, v1.16b, v2.16b, #n  // Concatenate v1:v2 and extract 16 bytes at offset n
ZIP1 v0.4s, v1.4s, v2.4s         // Interleave lower halves
ZIP2 v0.4s, v1.4s, v2.4s         // Interleave upper halves
UZP1 v0.4s, v1.4s, v2.4s         // Deinterleave even lanes
TRN1 v0.4s, v1.4s, v2.4s         // Transpose even lanes
```

## Integer ↔ Float Conversion (Vector)

```arm64
SCVTF  v0.4s, v1.4s           // 4 × int32 → float32
UCVTF  v0.4s, v1.4s           // 4 × uint32 → float32
FCVTZS v0.4s, v1.4s           // 4 × float32 → int32 (truncate)
FCVTZU v0.4s, v1.4s           // 4 × float32 → uint32 (truncate)
```

## Performance Tips

- **Avoid lane mixing** — extracting individual elements to GP registers is slow
- **Use FMLA** instead of FMUL+FADD — single-instruction, single-rounding
- **Pipeline NEON** — submit multiple independent SIMD ops to fill execution units
- **Use PRFM** — prefetch data into cache before you need it

```arm64
PRFM PLDL1KEEP, [x0, #64]    // Prefetch 64 bytes ahead into L1 data cache
```

## Real-World Use Cases on Apple Silicon

Apple's Neural Engine handles heavy ML workloads, but for custom SIMD in apps:
- **Image processing**: Apply filters to 16 pixels per cycle
- **Audio DSP**: FIR/IIR filters, FFT butterflies
- **Cryptography**: AES instructions, SHA hardware acceleration
- **String processing**: Search/compare 16 bytes at a time
