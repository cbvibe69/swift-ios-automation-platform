import Foundation

/// Functions for detecting hardware capabilities and calculating simulator counts
public func detectHardwareCapabilities() async throws -> HardwareSpec {
    let physicalMemory = HardwareDetection.memorySize()
    let processorCount = HardwareDetection.cpuCoreCount()
    let architecture = HardwareDetection.architecture()
    
    let memoryGB = Int(physicalMemory / (1024 * 1024 * 1024))
    
    return HardwareSpec(
        cpuCores: processorCount,
        totalMemoryGB: memoryGB,
        architecture: architecture
    )
}

/// Calculate optimal simulator count based on hardware specs
public func calculateOptimalSimulatorCount(hardwareSpec: HardwareSpec, reservedMemoryGB: Int = 4) -> Int {
    // Reserve some memory for the system and other apps
    let availableMemoryGB = hardwareSpec.totalMemoryGB - reservedMemoryGB
    
    // Each simulator typically uses about 2GB of RAM
    let simulatorMemoryGB = 2
    let memoryBasedCount = max(1, availableMemoryGB / simulatorMemoryGB)
    
    // CPU-based calculation: leave some cores for system
    let availableCores = max(1, hardwareSpec.cpuCores - 2)
    let cpuBasedCount = max(1, availableCores / 2) // 2 cores per simulator for good performance
    
    // Take the minimum to avoid resource exhaustion
    return min(memoryBasedCount, cpuBasedCount, 8) // Cap at 8 simulators for stability
}

/// Determine whether the current machine is running on Apple Silicon.
public func detectAppleSilicon() async -> Bool {
    return HardwareDetection.isAppleSilicon()
}

/// Rough heuristic to detect M2 Max-class machines.
public func detectM2MaxSpecifically() async -> Bool {
    return HardwareDetection.isMacStudioM2Max()
}
