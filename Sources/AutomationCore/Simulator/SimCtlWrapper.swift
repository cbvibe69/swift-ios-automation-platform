import Foundation
import Logging
import Subprocess

/// Swift wrapper for iOS Simulator Control (simctl) operations
public actor SimCtlWrapper {
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - Device Management
    
    /// List all available simulator devices
    public func listDevices() async throws -> [SimulatorDevice] {
        let command = ["xcrun", "simctl", "list", "devices", "--json"]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.commandFailed("Failed to list devices: \(result.errorOutput)")
        }
        
        return try parseDevicesFromJSON(result.output)
    }
    
    /// List available device types
    public func listDeviceTypes() async throws -> [String] {
        let command = ["xcrun", "simctl", "list", "devicetypes", "--json"]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.commandFailed("Failed to list device types: \(result.errorOutput)")
        }
        
        return try parseDeviceTypesFromJSON(result.output)
    }
    
    /// List available runtimes
    public func listRuntimes() async throws -> [String] {
        let command = ["xcrun", "simctl", "list", "runtimes", "--json"]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.commandFailed("Failed to list runtimes: \(result.errorOutput)")
        }
        
        return try parseRuntimesFromJSON(result.output)
    }
    
    // MARK: - Device Lifecycle
    
    /// Boot a simulator device
    public func bootDevice(_ deviceId: String) async throws -> SimulatorBootResult {
        let startTime = ContinuousClock.now
        
        // Check if already booted
        let devices = try await listDevices()
        if let device = devices.first(where: { $0.udid == deviceId }) {
            if device.state == "Booted" {
                logger.info("Device \(deviceId) already booted")
                return SimulatorBootResult(
                    success: true,
                    bootTime: 0,
                    wasAlreadyBooted: true
                )
            }
        }
        
        let command = ["xcrun", "simctl", "boot", deviceId]
        let result = try await executeCommand(command)
        
        let bootTime = startTime.duration(to: .now)
        
        if result.exitCode == 0 {
            logger.info("Device \(deviceId) booted successfully in \(bootTime.formatted())")
            return SimulatorBootResult(
                success: true,
                bootTime: bootTime.timeInterval,
                wasAlreadyBooted: false
            )
        } else {
            throw SimulatorError.bootFailed("Failed to boot device \(deviceId): \(result.errorOutput)")
        }
    }
    
    /// Shutdown a simulator device
    public func shutdownDevice(_ deviceId: String) async throws {
        let command = ["xcrun", "simctl", "shutdown", deviceId]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.shutdownFailed("Failed to shutdown device \(deviceId): \(result.errorOutput)")
        }
        
        logger.info("Device \(deviceId) shutdown successfully")
    }
    
    /// Erase all content and settings for a device
    public func eraseDevice(_ deviceId: String) async throws {
        let command = ["xcrun", "simctl", "erase", deviceId]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.eraseFailed("Failed to erase device \(deviceId): \(result.errorOutput)")
        }
        
        logger.info("Device \(deviceId) erased successfully")
    }
    
    /// Delete a simulator device
    public func deleteDevice(_ deviceId: String) async throws {
        let command = ["xcrun", "simctl", "delete", deviceId]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.deleteFailed("Failed to delete device \(deviceId): \(result.errorOutput)")
        }
        
        logger.info("Device \(deviceId) deleted successfully")
    }
    
    /// Create a new simulator device
    public func createDevice(name: String, deviceType: String, runtime: String) async throws -> String {
        let command = ["xcrun", "simctl", "create", name, deviceType, runtime]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.createFailed("Failed to create device: \(result.errorOutput)")
        }
        
        let deviceId = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Created device '\(name)' with ID: \(deviceId)")
        return deviceId
    }
    
    // MARK: - App Management
    
    /// Install an app on the simulator
    public func installApp(deviceId: String, appPath: String) async throws {
        let command = ["xcrun", "simctl", "install", deviceId, appPath]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.installFailed("Failed to install app: \(result.errorOutput)")
        }
        
        logger.info("App installed successfully on device \(deviceId)")
    }
    
    /// Uninstall an app from the simulator
    public func uninstallApp(deviceId: String, bundleId: String) async throws {
        let command = ["xcrun", "simctl", "uninstall", deviceId, bundleId]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.uninstallFailed("Failed to uninstall app: \(result.errorOutput)")
        }
        
        logger.info("App \(bundleId) uninstalled successfully from device \(deviceId)")
    }
    
    /// Launch an app on the simulator
    public func launchApp(deviceId: String, bundleId: String, arguments: [String] = []) async throws -> Int {
        var command = ["xcrun", "simctl", "launch", deviceId, bundleId]
        command.append(contentsOf: arguments)
        
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.launchFailed("Failed to launch app: \(result.errorOutput)")
        }
        
        // Extract process ID from output
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = output.range(of: ": "), 
           let pidString = output[range.upperBound...].components(separatedBy: " ").first,
           let pid = Int(pidString) {
            logger.info("Launched app \(bundleId) with PID: \(pid)")
            return pid
        }
        
        logger.info("Launched app \(bundleId) (PID unknown)")
        return 0
    }
    
    /// Terminate an app on the simulator
    public func terminateApp(deviceId: String, bundleId: String) async throws {
        let command = ["xcrun", "simctl", "terminate", deviceId, bundleId]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.terminateFailed("Failed to terminate app: \(result.errorOutput)")
        }
        
        logger.info("App \(bundleId) terminated successfully")
    }
    
    // MARK: - I/O Operations
    
    /// Take a screenshot of the simulator
    public func takeScreenshot(deviceId: String, outputPath: String? = nil) async throws -> String {
        let finalPath = outputPath ?? generateScreenshotPath()
        let command = ["xcrun", "simctl", "io", deviceId, "screenshot", finalPath]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.screenshotFailed("Failed to take screenshot: \(result.errorOutput)")
        }
        
        logger.info("Screenshot saved to: \(finalPath)")
        return finalPath
    }
    
    /// Record video of the simulator
    public func recordVideo(deviceId: String, outputPath: String? = nil) async throws -> String {
        let finalPath = outputPath ?? generateVideoPath()
        let command = ["xcrun", "simctl", "io", deviceId, "recordVideo", finalPath]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.recordingFailed("Failed to record video: \(result.errorOutput)")
        }
        
        logger.info("Video recorded to: \(finalPath)")
        return finalPath
    }
    
    // MARK: - Device State Management
    
    /// Get current device state
    public func getDeviceState(_ deviceId: String) async throws -> String {
        let devices = try await listDevices()
        guard let device = devices.first(where: { $0.udid == deviceId }) else {
            throw SimulatorError.deviceNotFound("Device \(deviceId) not found")
        }
        return device.state
    }
    
    /// Check if device is booted
    public func isDeviceBooted(_ deviceId: String) async throws -> Bool {
        let state = try await getDeviceState(deviceId)
        return state == "Booted"
    }
    
    /// Wait for device to boot (with timeout)
    public func waitForBoot(deviceId: String, timeout: TimeInterval = 60) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if try await isDeviceBooted(deviceId) {
                logger.info("Device \(deviceId) is now booted")
                return
            }
            
            try await Task.sleep(for: .seconds(2))
        }
        
        throw SimulatorError.bootTimeout("Device \(deviceId) failed to boot within \(timeout) seconds")
    }
    
    // MARK: - Utility Operations
    
    /// Get device logs
    public func getLogs(deviceId: String, since: Date? = nil) async throws -> String {
        var command = ["xcrun", "simctl", "spawn", deviceId, "log", "show"]
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            command.append(contentsOf: ["--start", formatter.string(from: since)])
        }
        
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.logsFailed("Failed to get logs: \(result.errorOutput)")
        }
        
        return result.output
    }
    
    /// Open URL in simulator
    public func openURL(deviceId: String, url: String) async throws {
        let command = ["xcrun", "simctl", "openurl", deviceId, url]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.openURLFailed("Failed to open URL: \(result.errorOutput)")
        }
        
        logger.info("Opened URL \(url) on device \(deviceId)")
    }
    
    /// Set device location
    public func setLocation(deviceId: String, latitude: Double, longitude: Double) async throws {
        let command = ["xcrun", "simctl", "location", deviceId, "set", "\(latitude),\(longitude)"]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            throw SimulatorError.locationFailed("Failed to set location: \(result.errorOutput)")
        }
        
        logger.info("Set location to \(latitude),\(longitude) on device \(deviceId)")
    }
    
    // MARK: - Helper Methods
    
    private func executeCommand(_ command: [String]) async throws -> CommandResult {
        logger.debug("Executing simctl command: \(command.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        return CommandResult(
            exitCode: Int(process.terminationStatus),
            output: output,
            errorOutput: errorOutput
        )
    }
    
    private func parseDevicesFromJSON(_ jsonString: String) throws -> [SimulatorDevice] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SimulatorError.parseError("Invalid JSON data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let devices = json?["devices"] as? [String: Any] else {
            throw SimulatorError.parseError("Invalid devices structure")
        }
        
        var result: [SimulatorDevice] = []
        
        for (runtime, deviceList) in devices {
            guard let deviceArray = deviceList as? [[String: Any]] else { continue }
            
            for deviceInfo in deviceArray {
                guard let udid = deviceInfo["udid"] as? String,
                      let name = deviceInfo["name"] as? String,
                      let deviceType = deviceInfo["deviceTypeIdentifier"] as? String,
                      let state = deviceInfo["state"] as? String else {
                    continue
                }
                
                let device = SimulatorDevice(
                    udid: udid,
                    name: name,
                    deviceType: deviceType,
                    runtime: runtime,
                    state: state
                )
                result.append(device)
            }
        }
        
        return result
    }
    
    private func parseDeviceTypesFromJSON(_ jsonString: String) throws -> [String] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SimulatorError.parseError("Invalid JSON data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let deviceTypes = json?["devicetypes"] as? [[String: Any]] else {
            throw SimulatorError.parseError("Invalid device types structure")
        }
        
        return deviceTypes.compactMap { $0["identifier"] as? String }
    }
    
    private func parseRuntimesFromJSON(_ jsonString: String) throws -> [String] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SimulatorError.parseError("Invalid JSON data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let runtimes = json?["runtimes"] as? [[String: Any]] else {
            throw SimulatorError.parseError("Invalid runtimes structure")
        }
        
        return runtimes.compactMap { $0["identifier"] as? String }
    }
    
    private func generateScreenshotPath() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("simulator_screenshot_\(timestamp).png").path
    }
    
    private func generateVideoPath() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("simulator_video_\(timestamp).mov").path
    }
}

// MARK: - Supporting Types

public struct CommandResult: Sendable {
    public let exitCode: Int
    public let output: String
    public let errorOutput: String
}

public struct SimulatorBootResult: Sendable {
    public let success: Bool
    public let bootTime: TimeInterval
    public let wasAlreadyBooted: Bool
}

public enum SimulatorError: Error, LocalizedError {
    case commandFailed(String)
    case parseError(String)
    case deviceNotFound(String)
    case bootFailed(String)
    case shutdownFailed(String)
    case eraseFailed(String)
    case deleteFailed(String)
    case createFailed(String)
    case installFailed(String)
    case uninstallFailed(String)
    case launchFailed(String)
    case terminateFailed(String)
    case screenshotFailed(String)
    case recordingFailed(String)
    case bootTimeout(String)
    case logsFailed(String)
    case openURLFailed(String)
    case locationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message),
             .parseError(let message),
             .deviceNotFound(let message),
             .bootFailed(let message),
             .shutdownFailed(let message),
             .eraseFailed(let message),
             .deleteFailed(let message),
             .createFailed(let message),
             .installFailed(let message),
             .uninstallFailed(let message),
             .launchFailed(let message),
             .terminateFailed(let message),
             .screenshotFailed(let message),
             .recordingFailed(let message),
             .bootTimeout(let message),
             .logsFailed(let message),
             .openURLFailed(let message),
             .locationFailed(let message):
            return message
        }
    }
}

extension ContinuousClock.Instant.Duration {
    var timeInterval: TimeInterval {
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
} 