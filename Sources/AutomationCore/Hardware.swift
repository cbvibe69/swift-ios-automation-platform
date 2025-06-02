import Foundation

/// Hardware capability detection for Mac Studio M2 Max optimization
public func detectHardwareCapabilities() async throws -> HardwareSpec {
    let processInfo = ProcessInfo.processInfo

    // Get system information
    let physicalMemory = processInfo.physicalMemory
    let processorCount = processInfo.processorCount

    // Detect if this is Mac Studio M2 Max (or similar Apple Silicon)
    let isAppleSilicon = await detectAppleSilicon()
    let isM2Max = await detectM2MaxSpecifically()

    return HardwareSpec(
        totalMemoryGB: Int(physicalMemory / (1024 * 1024 * 1024)),
        cpuCores: processorCount,
        isAppleSilicon: isAppleSilicon,
        isM2Max: isM2Max,
        recommendedSimulators: calculateOptimalSimulatorCount(
            memoryGB: Int(physicalMemory / (1024 * 1024 * 1024)),
            cores: processorCount
        )
    )
}

/// Detect if running on Apple Silicon
public func detectAppleSilicon() async -> Bool {
    #if arch(arm64)
    return true
    #else
    return false
    #endif
}

/// Detect if the machine specifically matches an M2 Max configuration
public func detectM2MaxSpecifically() async -> Bool {
    // This would require more specific hardware detection
    // For now, assume M2 Max if we have 32GB+ RAM and 10+ cores on Apple Silicon
    let processInfo = ProcessInfo.processInfo
    let memoryGB = Int(processInfo.physicalMemory / (1024 * 1024 * 1024))
    let cores = processInfo.processorCount

    return await detectAppleSilicon() && memoryGB >= 32 && cores >= 10
}

/// Calculate the optimal number of iOS simulators based on system resources
public func calculateOptimalSimulatorCount(memoryGB: Int, cores: Int) -> Int {
    // Conservative calculation: 2GB per simulator, leave 8GB for system
    let availableMemory = memoryGB - 8
    let memoryBasedLimit = max(1, availableMemory / 2)

    // CPU-based limit: assume 1-2 simulators per core
    let cpuBasedLimit = cores * 2

    // Return the more conservative estimate
    return min(memoryBasedLimit, cpuBasedLimit, 12) // Cap at 12 simulators
}
