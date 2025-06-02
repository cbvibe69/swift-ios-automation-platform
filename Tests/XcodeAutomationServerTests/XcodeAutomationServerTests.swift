import XCTest
import Logging
@testable import AutomationCore

final class XcodeAutomationServerTests: XCTestCase {
    
    func testHardwareDetection() async throws {
        // Test hardware capability detection
        let hardwareSpec = try await detectHardwareCapabilities()
        
        // Verify basic properties
        XCTAssertGreaterThan(hardwareSpec.totalMemoryGB, 0)
        XCTAssertGreaterThan(hardwareSpec.cpuCores, 0)
        
        print("Detected hardware: \(hardwareSpec.cpuCores) cores, \(hardwareSpec.totalMemoryGB)GB RAM, \(hardwareSpec.architecture)")
    }
    
    func testServerConfiguration() throws {
        // Test server configuration creation
        let logger = Logger(label: "test")
        
        let config = ServerConfiguration(
            logger: logger,
            maxResourceUtilization: 85,
            developmentMode: true
        )
        
        XCTAssertEqual(config.maxResourceUtilization, 85)
        XCTAssertTrue(config.developmentMode)
    }
    
    func testSimulatorCalculation() async throws {
        // Test optimal simulator count calculation
        let hardwareSpec = try await detectHardwareCapabilities()
        let count = calculateOptimalSimulatorCount(hardwareSpec: hardwareSpec)
        
        // Should be between 1 and number of cores
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(count, hardwareSpec.cpuCores)
        
        print("Optimal simulator count for detected hardware: \(count)")
    }
    
    func testPerformanceBaseline() async throws {
        // Performance baseline test
        let startTime = ContinuousClock.now
        
        // Simulate some work
        try await Task.sleep(for: .milliseconds(100))
        
        let duration = startTime.duration(to: .now)
        
        // Should complete quickly (baseline for future performance tests)
        XCTAssertLessThan(duration.timeInterval, 0.2, "Baseline performance test")
        
        print("Baseline performance: \(duration.formatted())")
    }
}