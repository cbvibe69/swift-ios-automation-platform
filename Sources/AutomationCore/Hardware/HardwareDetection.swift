import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Detects hardware details using sysctl.
public enum HardwareDetection {
    /// Number of logical CPU cores.
    public static func cpuCoreCount() -> Int {
        #if canImport(Darwin)
        var cores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.ncpu", &cores, &size, nil, 0) == 0 {
            return Int(cores)
        }
        #endif
        return ProcessInfo.processInfo.processorCount
    }

    /// Total physical memory size in bytes.
    public static func memorySize() -> UInt64 {
        #if canImport(Darwin)
        var mem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &mem, &size, nil, 0) == 0 {
            return mem
        }
        #endif
        return UInt64(ProcessInfo.processInfo.physicalMemory)
    }

    /// Returns the Apple Silicon model string if available.
    public static func appleSiliconModel() -> String? {
        #if canImport(Darwin)
        var buffer = [CChar](repeating: 0, count: 256)
        var size = buffer.count
        if sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 {
            return String(cString: buffer)
        }
        #endif
        return nil
    }

    /// Detects whether the current machine is an Apple Silicon Mac.
    public static func isAppleSilicon() -> Bool {
        if let model = appleSiliconModel() {
            return model.contains("Apple")
        }
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// Detects specifically if the machine uses the M2 Max chip.
    /// This is a simple string match on the CPU brand string which is
    /// sufficient for distinguishing Mac Studio M2 Max machines.
    public static func isMacStudioM2Max() -> Bool {
        guard let model = appleSiliconModel() else { return false }
        return model.contains("M2 Max")
    }
}
