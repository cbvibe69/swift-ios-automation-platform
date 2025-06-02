import Foundation
import Logging
import AutomationCore

// MARK: - Main Entry Point

@main
struct XcodeAutomationMain {
    static func main() async {
        // Setup logging
        let logger = Logger(label: "swift-ios-automation-platform")
        
        do {
            logger.info("🚀 Starting Swift iOS Automation Platform")
            
            // Create server configuration
            let configuration = ServerConfiguration(
                logger: logger,
                maxResourceUtilization: 80,
                developmentMode: true
            )
            
            // Initialize MCP server
            let server = try await XcodeAutomationMCPServer(configuration: configuration)
            
            // Start server with stdio transport (secure, no network)
            logger.info("🎯 Starting MCP server with stdio transport")
            try await server.startStdioTransport()
            
        } catch {
            logger.error("💥 Failed to start server: \(error)")
            exit(1)
        }
    }
}
