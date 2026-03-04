import SwiftUI
import Foundation

// MARK: - Memory State

struct MemoryState {
    var segments: [MemorySegment]
    var registers: [Register]
    var stackFrames: [StackFrame]
    var highlightedSegmentNames: Set<String>

    init(highlightedSegments: [String] = []) {
        self.segments = MemorySegment.arm64DefaultLayout()
        self.registers = Register.arm64Registers()
        self.stackFrames = []
        self.highlightedSegmentNames = Set(highlightedSegments)
    }
}

// MARK: - Memory Segment

struct MemorySegment: Identifiable {
    let id = UUID()
    var name: String
    var subtitle: String
    var startAddress: UInt64
    var size: UInt64
    var permissions: String
    var description: String
    var color: Color
    var sections: [MemorySection]
    var isExpanded: Bool = true

    var endAddress: UInt64 { startAddress &+ size }

    var formattedStart: String { String(format: "0x%011X", startAddress) }
    var formattedEnd: String { String(format: "0x%011X", endAddress) }
    var formattedSize: String {
        if size >= 1024 * 1024 {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        } else if size >= 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return "\(size) B"
        }
    }

    static func arm64DefaultLayout() -> [MemorySegment] {
        [
            MemorySegment(
                name: "STACK",
                subtitle: "Grows downward ↓",
                startAddress: 0x7_FFFF_F000,
                size: 0x8_000,
                permissions: "rw-",
                description: "Function call frames, local variables, return addresses. Managed automatically by function prologues/epilogues.",
                color: .purple,
                sections: [
                    MemorySection(name: "Frame Pointer (x29)", offset: 0, size: 8, description: "Saved frame pointer from caller"),
                    MemorySection(name: "Link Register (x30)", offset: 8, size: 8, description: "Return address to caller"),
                    MemorySection(name: "Local Variables", offset: 16, size: 32, description: "Stack-allocated function variables"),
                ]
            ),
            MemorySegment(
                name: "HEAP",
                subtitle: "Grows upward ↑",
                startAddress: 0x2_0000_0000,
                size: 0x1_0000,
                permissions: "rw-",
                description: "Dynamically allocated memory via malloc/free. Managed by the allocator. In ARM64 ABI, x0 holds the address returned by malloc.",
                color: Color(red: 1.0, green: 0.6, blue: 0.0),
                sections: []
            ),
            MemorySegment(
                name: "__DATA",
                subtitle: "Mutable data segment",
                startAddress: 0x1_0000_4000,
                size: 0x2000,
                permissions: "rw-",
                description: "Mutable global and static data. Loaded from the Mach-O binary at startup.",
                color: .green,
                sections: [
                    MemorySection(name: "__data", offset: 0x0000, size: 0x1000, description: "Initialized global variables (.data)"),
                    MemorySection(name: "__bss", offset: 0x1000, size: 0x0800, description: "Uninitialized globals, zero-filled (.bss)"),
                    MemorySection(name: "__common", offset: 0x1800, size: 0x0800, description: "Common symbols, zero-filled"),
                ]
            ),
            MemorySegment(
                name: "__TEXT",
                subtitle: "Read-only code segment",
                startAddress: 0x1_0000_0000,
                size: 0x4000,
                permissions: "r-x",
                description: "Executable machine code and read-only constants. The PC register points into this segment during execution.",
                color: .blue,
                sections: [
                    MemorySection(name: "__text", offset: 0x0000, size: 0x2000, description: "Compiled machine code instructions"),
                    MemorySection(name: "__const", offset: 0x2000, size: 0x0800, description: "Read-only constants"),
                    MemorySection(name: "__cstring", offset: 0x2800, size: 0x0800, description: "C string literals (.asciz)"),
                    MemorySection(name: "__unwind_info", offset: 0x3000, size: 0x1000, description: "Stack unwinding metadata"),
                ]
            ),
        ]
    }
}

// MARK: - Memory Section

struct MemorySection: Identifiable {
    let id = UUID()
    var name: String
    var offset: UInt64
    var size: UInt64
    var description: String

    var formattedOffset: String { String(format: "+0x%04X", offset) }
}

// MARK: - Register

struct Register: Identifiable {
    let id = UUID()
    var name: String
    var alias: String?
    var value: UInt64
    var description: String
    var category: Category
    var isChanged: Bool = false

    var hexValue: String { String(format: "0x%016X", value) }
    var decValue: String { "\(value)" }

    var displayName: String {
        if let alias = alias { return "\(name) / \(alias)" }
        return name
    }

    enum Category: String, CaseIterable {
        case general  = "General Purpose"
        case special  = "Special Purpose"
        case flags    = "Flags"
    }

    static func arm64Registers() -> [Register] {
        var regs: [Register] = []

        // x0–x7: arguments / return values
        let argDescs = ["1st argument / return value", "2nd argument / return value",
                        "3rd argument", "4th argument", "5th argument",
                        "6th argument", "7th argument", "8th argument"]
        for i in 0...7 {
            regs.append(Register(name: "x\(i)", value: 0, description: argDescs[i], category: .general))
        }

        // x8: indirect result
        regs.append(Register(name: "x8", value: 0, description: "Indirect result location / syscall number", category: .general))

        // x9–x15: caller-saved temporaries
        for i in 9...15 {
            regs.append(Register(name: "x\(i)", value: 0, description: "Caller-saved temporary register", category: .general))
        }

        // x16–x17: intra-procedure-call
        regs.append(Register(name: "x16", alias: "ip0", value: 0, description: "Intra-procedure-call scratch / syscall number (macOS)", category: .general))
        regs.append(Register(name: "x17", alias: "ip1", value: 0, description: "Intra-procedure-call scratch", category: .general))

        // x18: platform register
        regs.append(Register(name: "x18", value: 0, description: "Platform reserved (do not use)", category: .general))

        // x19–x28: callee-saved
        for i in 19...28 {
            regs.append(Register(name: "x\(i)", value: 0, description: "Callee-saved register (preserved across calls)", category: .general))
        }

        // Special registers
        regs.append(Register(name: "x29", alias: "fp", value: 0, description: "Frame pointer — base of current stack frame", category: .special))
        regs.append(Register(name: "x30", alias: "lr", value: 0, description: "Link register — return address set by BL/BLR", category: .special))
        regs.append(Register(name: "sp", value: 0x7FFFFFE000, description: "Stack pointer — must be 16-byte aligned at calls", category: .special))
        regs.append(Register(name: "pc", value: 0x100000000, description: "Program counter — address of current instruction", category: .special))
        regs.append(Register(name: "xzr", alias: "wzr", value: 0, description: "Zero register — always reads 0, writes discarded", category: .special))

        // Flags
        regs.append(Register(name: "nzcv", value: 0, description: "Condition flags: N(egative) Z(ero) C(arry) o(V)erflow", category: .flags))
        regs.append(Register(name: "fpsr", value: 0, description: "Floating-point status register", category: .flags))

        return regs
    }
}

// MARK: - Stack Frame

struct StackFrame: Identifiable {
    let id = UUID()
    var functionName: String
    var returnAddress: UInt64
    var framePointer: UInt64
    var savedRegisters: [(name: String, value: UInt64)]
    var localVariables: [(name: String, size: Int, value: String)]
}
