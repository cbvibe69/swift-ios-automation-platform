import Foundation

/// Functions for detecting hardware capabilities and calculating simulator counts
public func detectHardwareCapabilities() async throws -> HardwareSpec {
    let physicalMemory = HardwareDetection.memorySize()
    let processorCount = HardwareDetection.cpuCoreCount()

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

/// Determine whether the current machine is running on Apple Silicon.
public func detectAppleSilicon() async -> Bool {
    HardwareDetection.isAppleSilicon()
}

/// Rough heuristic to detect M2 Max-class machines.
public func detectM2MaxSpecifically() async -> Bool {
    HardwareDetection.isMacStudioM2Max()
}

/// Calculate an optimal simulator count based on available memory and cores.
public func calculateOptimalSimulatorCount(memoryGB: Int, cores: Int) -> Int {
    let availableMemory = memoryGB - 8
    let memoryBasedLimit = max(1, availableMemory / 2)
    let cpuBasedLimit = cores * 2
    return min(memoryBasedLimit, cpuBasedLimit, 12)
}
