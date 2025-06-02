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
        XCTAssertGreaterThan(hardwareSpec.recommendedSimulators, 0)
        
        print("Detected hardware: \(hardwareSpec.description)")
    }
    
    func testServerConfiguration() throws {
        // Test server configuration creation
        let logger = Logger(label: "test")
        let hardwareSpec = HardwareSpec(
            totalMemoryGB: 32,
            cpuCores: 12,
            isAppleSilicon: true,
            isM2Max: true,
            recommendedSimulators: 8
        )
        
        let config = ServerConfiguration(
            maxResourceUtilization: 85,
            developmentMode: true,
            maximumSecurity: true,
            hardwareSpec: hardwareSpec,
            logger: logger
        )
        
        XCTAssertEqual(config.maxResourceUtilization, 85)
        XCTAssertTrue(config.developmentMode)
        XCTAssertTrue(config.maximumSecurity)
        XCTAssertTrue(config.hardwareSpec.isM2Max)
    }
    
    func testSimulatorCalculation() {
        // Test optimal simulator count calculation
        let count = calculateOptimalSimulatorCount(memoryGB: 32, cores: 12)
        
        // Should be between 1 and 12 simulators
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(count, 12)
        
        print("Optimal simulator count for Mac Studio M2 Max: \(count)")
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
