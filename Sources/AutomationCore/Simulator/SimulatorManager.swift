import Foundation
import Logging
import Collections

/// Actor responsible for managing iOS simulators with resource awareness and concurrency control
public actor SimulatorManager {
    private let logger: Logger
    private let simctl: SimCtlWrapper
    private let resourceManager: ResourceManager
    private let maxConcurrentDevices: Int
    
    // State tracking
    private var activeDevices: [String: ManagedDevice] = [:]
    private var pendingOperations: Deque<SimulatorOperation> = []
    private var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    
    public init(logger: Logger, resourceManager: ResourceManager, maxConcurrentDevices: Int = 8) {
        self.logger = logger
        self.simctl = SimCtlWrapper(logger: logger)
        self.resourceManager = resourceManager
        self.maxConcurrentDevices = maxConcurrentDevices
    }
    
    deinit {
        monitoringTask?.cancel()
    }
    
    // MARK: - Device Lifecycle Management
    
    /// Boot simulators with resource awareness
    public func bootDevices(_ deviceIds: [String]) async throws -> [SimulatorBootResult] {
        logger.info("🚀 Booting \(deviceIds.count) simulators with resource management")
        
        let optimalCount = await resourceManager.calculateOptimalSimulatorCount(
            requestedDevices: deviceIds.count
        )
        
        guard deviceIds.count <= optimalCount else {
            logger.warning("Requested \(deviceIds.count) devices, but system can optimally handle \(optimalCount)")
            throw SimulatorManagerError.resourceLimitExceeded("Cannot boot \(deviceIds.count) devices. Maximum optimal: \(optimalCount)")
        }
        
        var results: [SimulatorBootResult] = []
        
        // Boot devices in parallel, but respect resource limits
        let batches = deviceIds.chunked(into: min(optimalCount, 4)) // Process in batches of 4
        
        for batch in batches {
            let batchResults = try await withThrowingTaskGroup(of: SimulatorBootResult.self) { group in
                for deviceId in batch {
                    group.addTask {
                        try await self.bootSingleDevice(deviceId)
                    }
                }
                
                var batchResults: [SimulatorBootResult] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            
            results.append(contentsOf: batchResults)
            
            // Brief pause between batches to allow system to stabilize
            if batch != batches.last {
                try await Task.sleep(for: .seconds(2))
            }
        }
        
        await startHealthMonitoring()
        
        logger.info("✅ Successfully booted \(results.count) simulators")
        return results
    }
    
    /// Boot a single simulator with tracking
    private func bootSingleDevice(_ deviceId: String) async throws -> SimulatorBootResult {
        // Check if already managed
        if let existing = activeDevices[deviceId] {
            if existing.state == .booted {
                logger.info("Device \(deviceId) already booted and managed")
                return SimulatorBootResult(success: true, bootTime: 0, wasAlreadyBooted: true)
            }
        }
        
        // Update state to booting
        activeDevices[deviceId] = ManagedDevice(
            deviceId: deviceId,
            state: .booting,
            bootTime: Date(),
            lastHealthCheck: Date()
        )
        
        do {
            let result = try await simctl.bootDevice(deviceId)
            
            // Update state to booted
            activeDevices[deviceId]?.state = .booted
            activeDevices[deviceId]?.bootTime = Date()
            
            logger.info("✅ Device \(deviceId) booted successfully")
            return result
            
        } catch {
            // Update state to failed
            activeDevices[deviceId]?.state = .failed
            logger.error("❌ Failed to boot device \(deviceId): \(error)")
            throw error
        }
    }
    
    /// Shutdown all managed simulators
    public func shutdownAll() async throws {
        logger.info("🛑 Shutting down all \(activeDevices.count) managed simulators")
        
        let deviceIds = Array(activeDevices.keys)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for deviceId in deviceIds {
                group.addTask {
                    do {
                        try await self.simctl.shutdownDevice(deviceId)
                        await self.updateDeviceState(deviceId: deviceId, state: .shutdown)
                        self.logger.info("✅ Device \(deviceId) shutdown successfully")
                    } catch {
                        self.logger.error("❌ Failed to shutdown device \(deviceId): \(error)")
                        // Continue with other devices
                    }
                }
            }
            
            // Wait for all shutdowns to complete
            try await group.waitForAll()
        }
        
        // Clean up tracking
        activeDevices.removeAll()
        stopHealthMonitoring()
        
        logger.info("✅ All simulators shutdown and cleaned up")
    }
    
    /// Shutdown specific devices
    public func shutdownDevices(_ deviceIds: [String]) async throws {
        logger.info("🛑 Shutting down \(deviceIds.count) specific simulators")
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for deviceId in deviceIds {
                group.addTask {
                    do {
                        try await self.simctl.shutdownDevice(deviceId)
                        await self.removeDeviceFromManagement(deviceId: deviceId)
                        self.logger.info("✅ Device \(deviceId) shutdown and removed from management")
                    } catch {
                        self.logger.error("❌ Failed to shutdown device \(deviceId): \(error)")
                        throw error
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    // MARK: - Private Actor-Isolated Methods
    
    private func updateDeviceState(deviceId: String, state: DeviceState) {
        activeDevices[deviceId]?.state = state
    }
    
    private func removeDeviceFromManagement(deviceId: String) {
        activeDevices.removeValue(forKey: deviceId)
    }
    
    // MARK: - App Management
    
    /// Install apps on multiple simulators concurrently
    public func installAppOnDevices(appPath: String, deviceIds: [String]) async throws -> [String: Bool] {
        logger.info("📲 Installing app on \(deviceIds.count) simulators: \(appPath)")
        
        var results: [String: Bool] = [:]
        
        try await withThrowingTaskGroup(of: (String, Bool).self) { group in
            for deviceId in deviceIds {
                group.addTask {
                    do {
                        try await self.simctl.installApp(deviceId: deviceId, appPath: appPath)
                        return (deviceId, true)
                    } catch {
                        self.logger.error("Failed to install app on \(deviceId): \(error)")
                        return (deviceId, false)
                    }
                }
            }
            
            for try await (deviceId, success) in group {
                results[deviceId] = success
            }
        }
        
        let successCount = results.values.filter { $0 }.count
        logger.info("✅ App installed on \(successCount)/\(deviceIds.count) simulators")
        
        return results
    }
    
    /// Launch apps on multiple simulators
    public func launchAppOnDevices(bundleId: String, deviceIds: [String]) async throws -> [String: Int] {
        logger.info("🚀 Launching app \(bundleId) on \(deviceIds.count) simulators")
        
        var results: [String: Int] = [:]
        
        try await withThrowingTaskGroup(of: (String, Int).self) { group in
            for deviceId in deviceIds {
                group.addTask {
                    do {
                        let pid = try await self.simctl.launchApp(deviceId: deviceId, bundleId: bundleId)
                        return (deviceId, pid)
                    } catch {
                        self.logger.error("Failed to launch app on \(deviceId): \(error)")
                        return (deviceId, 0)
                    }
                }
            }
            
            for try await (deviceId, pid) in group {
                results[deviceId] = pid
            }
        }
        
        let successCount = results.values.filter { $0 > 0 }.count
        logger.info("✅ App launched on \(successCount)/\(deviceIds.count) simulators")
        
        return results
    }
    
    // MARK: - Testing Matrix Management
    
    /// Create an optimal testing matrix based on available devices and hardware
    public func createTestingMatrix() async throws -> TestingMatrix {
        logger.info("🎯 Creating optimal testing matrix")
        
        let allDevices = try await simctl.listDevices()
        let availableDevices = allDevices.filter { $0.state == "Shutdown" || $0.state == "Booted" }
        
        let optimalCount = await resourceManager.calculateOptimalSimulatorCount(
            requestedDevices: availableDevices.count
        )
        
        var selectedDevices: [SimulatorDevice] = []
        
        // Prioritize device selection for comprehensive testing
        let priorities = [
            "iPhone 15 Pro",
            "iPhone 14",
            "iPad Pro",
            "iPhone SE",
            "iPhone 15 Plus",
            "iPad Air"
        ]
        
        for priority in priorities {
            if selectedDevices.count >= optimalCount { break }
            
            if let device = availableDevices.first(where: { $0.name.contains(priority) }) {
                selectedDevices.append(device)
            }
        }
        
        // Fill remaining slots with any available devices
        for device in availableDevices {
            if selectedDevices.count >= optimalCount { break }
            if !selectedDevices.contains(where: { $0.udid == device.udid }) {
                selectedDevices.append(device)
            }
        }
        
        let matrix = TestingMatrix(
            selectedDevices: selectedDevices,
            optimalConcurrency: optimalCount,
            estimatedTestTime: calculateEstimatedTestTime(deviceCount: selectedDevices.count),
            deviceTypes: selectedDevices.map { $0.name }
        )
        
        logger.info("✅ Created testing matrix with \(selectedDevices.count) devices")
        return matrix
    }
    
    /// Execute a testing matrix
    public func executeTestingMatrix(_ matrix: TestingMatrix, bundleId: String) async throws -> TestingMatrixResult {
        logger.info("🧪 Executing testing matrix with \(matrix.selectedDevices.count) devices")
        
        let startTime = ContinuousClock.now
        
        // Boot all devices in the matrix
        let deviceIds = matrix.selectedDevices.map { $0.udid }
        let bootResults = try await bootDevices(deviceIds)
        
        // Launch the app on all devices
        let launchResults = try await launchAppOnDevices(bundleId: bundleId, deviceIds: deviceIds)
        
        let executionTime = startTime.duration(to: .now)
        
        let result = TestingMatrixResult(
            matrix: matrix,
            bootResults: bootResults,
            launchResults: launchResults,
            totalExecutionTime: executionTime.timeInterval,
            successfulDevices: launchResults.values.filter { $0 > 0 }.count
        )
        
        logger.info("✅ Testing matrix executed in \(executionTime.formatted())")
        return result
    }
    
    // MARK: - Health Monitoring
    
    /// Start health monitoring for all managed devices
    public func startHealthMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("❤️ Starting health monitoring for \(activeDevices.count) devices")
        
        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await performHealthChecks()
                
                // Check every 30 seconds
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
    
    /// Stop health monitoring
    public func stopHealthMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        logger.info("🛑 Stopped health monitoring")
    }
    
    /// Perform health checks on all managed devices
    private func performHealthChecks() async {
        guard !activeDevices.isEmpty else { return }
        
        logger.debug("❤️ Performing health checks on \(activeDevices.count) devices")
        
        for (deviceId, managedDevice) in activeDevices {
            do {
                let isBooted = try await simctl.isDeviceBooted(deviceId)
                
                if isBooted && managedDevice.state != .booted {
                    activeDevices[deviceId]?.state = .booted
                    logger.info("✅ Device \(deviceId) recovered to booted state")
                } else if !isBooted && managedDevice.state == .booted {
                    activeDevices[deviceId]?.state = .failed
                    logger.warning("⚠️ Device \(deviceId) unexpectedly shutdown")
                }
                
                activeDevices[deviceId]?.lastHealthCheck = Date()
                
            } catch {
                logger.error("❌ Health check failed for device \(deviceId): \(error)")
                activeDevices[deviceId]?.state = .failed
            }
        }
    }
    
    // MARK: - Resource Optimization
    
    /// Get current resource usage and recommendations
    public func getResourceStatus() async -> SimulatorResourceStatus {
        let usage = await resourceManager.calculateOptimalSimulatorCount(requestedDevices: 10)
        let currentActive = activeDevices.values.filter { $0.state == .booted }.count
        
        return SimulatorResourceStatus(
            currentActiveDevices: currentActive,
            maxOptimalDevices: usage,
            availableSlots: max(0, usage - currentActive),
            memoryPressure: currentActive > usage * 8 / 10, // 80% threshold
            recommendations: generateResourceRecommendations(currentActive: currentActive, optimal: usage)
        )
    }
    
    private func generateResourceRecommendations(currentActive: Int, optimal: Int) -> [String] {
        var recommendations: [String] = []
        
        if currentActive > optimal {
            recommendations.append("Consider shutting down \(currentActive - optimal) simulators for optimal performance")
        } else if currentActive < optimal / 2 {
            recommendations.append("System can handle \(optimal - currentActive) more simulators")
        }
        
        if currentActive > 6 {
            recommendations.append("Monitor memory usage closely with \(currentActive) active simulators")
        }
        
        recommendations.append("Optimal concurrency for testing: \(min(optimal, 6))")
        
        return recommendations
    }
    
    // MARK: - Utility Methods
    
    /// Get status of all managed devices
    public func getManagedDeviceStatus() async -> [String: ManagedDevice] {
        return activeDevices
    }
    
    /// Clean up failed or orphaned devices
    public func cleanupFailedDevices() async throws {
        let failedDevices = activeDevices.filter { $0.value.state == .failed }.map { $0.key }
        
        guard !failedDevices.isEmpty else {
            logger.info("✅ No failed devices to clean up")
            return
        }
        
        logger.info("🧹 Cleaning up \(failedDevices.count) failed devices")
        
        for deviceId in failedDevices {
            do {
                try await simctl.shutdownDevice(deviceId)
                activeDevices.removeValue(forKey: deviceId)
                logger.info("✅ Cleaned up failed device: \(deviceId)")
            } catch {
                logger.error("❌ Failed to cleanup device \(deviceId): \(error)")
            }
        }
    }
    
    private func calculateEstimatedTestTime(deviceCount: Int) -> TimeInterval {
        // Base test time + overhead for multiple devices
        let baseTime: TimeInterval = 30 // seconds
        let concurrencyFactor = min(Double(deviceCount) / 4.0, 2.0) // Up to 2x slower with many devices
        return baseTime * concurrencyFactor
    }
}

// MARK: - Supporting Types

public struct ManagedDevice: Sendable {
    public let deviceId: String
    public var state: DeviceState
    public var bootTime: Date
    public var lastHealthCheck: Date
    
    public init(deviceId: String, state: DeviceState, bootTime: Date, lastHealthCheck: Date) {
        self.deviceId = deviceId
        self.state = state
        self.bootTime = bootTime
        self.lastHealthCheck = lastHealthCheck
    }
}

public enum DeviceState: Sendable {
    case shutdown
    case booting
    case booted
    case failed
}

public struct TestingMatrix: Sendable {
    public let selectedDevices: [SimulatorDevice]
    public let optimalConcurrency: Int
    public let estimatedTestTime: TimeInterval
    public let deviceTypes: [String]
}

public struct TestingMatrixResult: Sendable {
    public let matrix: TestingMatrix
    public let bootResults: [SimulatorBootResult]
    public let launchResults: [String: Int]
    public let totalExecutionTime: TimeInterval
    public let successfulDevices: Int
}

public struct SimulatorResourceStatus: Sendable {
    public let currentActiveDevices: Int
    public let maxOptimalDevices: Int
    public let availableSlots: Int
    public let memoryPressure: Bool
    public let recommendations: [String]
}

public struct SimulatorOperation: Sendable {
    public let id: UUID
    public let type: OperationType
    public let deviceId: String
    public let priority: Int
    
    public enum OperationType: Sendable {
        case boot
        case shutdown
        case install(appPath: String)
        case launch(bundleId: String)
    }
}

public enum SimulatorManagerError: Error, LocalizedError {
    case resourceLimitExceeded(String)
    case deviceNotManaged(String)
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .resourceLimitExceeded(let message),
             .deviceNotManaged(let message),
             .operationFailed(let message):
            return message
        }
    }
}

// MARK: - Collection Extension

extension Collection {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: Swift.min($0 + size, count))])
        }
    }
} 