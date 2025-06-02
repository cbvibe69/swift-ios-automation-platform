import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Snapshot of current system resource usage.
public struct ResourceUsage: Sendable {
    public let cpuUsage: Double      // 0.0 - 1.0
    public let memoryUsedBytes: UInt64
    public let diskReadBytes: UInt64
    public let diskWriteBytes: UInt64
}

/// Actor that samples system resources with minimal overhead.
public actor ResourceMonitor {
    private var lastCPUInfo = host_cpu_load_info()
    private var lastPageins: UInt64 = 0
    private var lastPageouts: UInt64 = 0
    private let pageSize: UInt64

    public init() {
        #if canImport(Darwin)
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        self.pageSize = UInt64(size)
        _ = sampleCPU()
        _ = vmStats()
        #else
        self.pageSize = 4096
        #endif
    }

    /// Collects a `ResourceUsage` snapshot.
    public func snapshot() -> ResourceUsage {
        let cpu = sampleCPU()
        let mem = vmStats()
        return ResourceUsage(cpuUsage: cpu,
                              memoryUsedBytes: mem.used,
                              diskReadBytes: mem.read,
                              diskWriteBytes: mem.written)
    }

    // MARK: - Private helpers
    private func sampleCPU() -> Double {
        #if canImport(Darwin)
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        defer { lastCPUInfo = info }
        let user = Double(info.cpu_ticks.0 - lastCPUInfo.cpu_ticks.0)
        let sys = Double(info.cpu_ticks.1 - lastCPUInfo.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 - lastCPUInfo.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 - lastCPUInfo.cpu_ticks.3)
        let total = user + sys + idle + nice
        return total > 0 ? (user + sys + nice) / total : 0
        #else
        return 0
        #endif
    }

    private func vmStats() -> (used: UInt64, read: UInt64, written: UInt64) {
        #if canImport(Darwin)
        var stat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        let used = (UInt64(stat.active_count) + UInt64(stat.inactive_count) + UInt64(stat.wire_count)) * pageSize
        let read = (UInt64(stat.pageins) - lastPageins) * pageSize
        let written = (UInt64(stat.pageouts) - lastPageouts) * pageSize
        lastPageins = UInt64(stat.pageins)
        lastPageouts = UInt64(stat.pageouts)
        return (used, read, written)
        #else
        return (0, 0, 0)
        #endif
    }
}
