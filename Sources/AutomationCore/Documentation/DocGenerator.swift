import Foundation
import Logging
import SystemPackage

/// Automatic API documentation generator for Swift iOS Automation Platform
public actor DocGenerator {
    private let logger: Logger
    private let fileManager = FileManager.default
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - Public API
    
    /// Generate comprehensive documentation for the project
    public func generateProjectDocumentation(
        projectPath: String,
        outputPath: String = "Documentation/Generated"
    ) async throws -> DocumentationResult {
        logger.info("📊 Generating project documentation: \(projectPath)")
        
        let startTime = ContinuousClock.now
        
        // Ensure output directory exists
        try createOutputDirectory(outputPath)
        
        // Scan project for Swift files
        let swiftFiles = try await scanForSwiftFiles(in: projectPath)
        logger.info("Found \(swiftFiles.count) Swift files to analyze")
        
        // Generate different types of documentation
        let apiDocs = try await generateAPIDocumentation(swiftFiles: swiftFiles)
        let architectureDocs = try await generateArchitectureDocumentation(projectPath: projectPath)
        let toolDocs = try await generateMCPToolDocumentation(projectPath: projectPath)
        
        // Write documentation files
        try await writeDocumentationFiles(
            apiDocs: apiDocs,
            architectureDocs: architectureDocs,
            toolDocs: toolDocs,
            outputPath: outputPath
        )
        
        let duration = startTime.duration(to: .now)
        logger.info("✅ Documentation generated in \(duration.formatted())")
        
        return DocumentationResult(
            apiDocsCount: apiDocs.count,
            architectureDocsCount: architectureDocs.count,
            toolDocsCount: toolDocs.count,
            generationTime: duration,
            outputPath: outputPath
        )
    }
    
    /// Generate live documentation for MCP tools
    public func generateLiveMCPToolDocumentation(
        toolRegistry: MCPToolRegistry
    ) async throws -> String {
        logger.info("📋 Generating live MCP tool documentation")
        
        let tools = await toolRegistry.getRegisteredTools()
        var markdown = "# MCP Tools Reference\n\n"
        markdown += "*Auto-generated on \(Date().formatted())*\n\n"
        
        for tool in tools {
            markdown += try await generateToolDocumentationSection(tool: tool)
        }
        
        return markdown
    }
    
    // MARK: - Swift File Analysis
    
    private func scanForSwiftFiles(in projectPath: String) async throws -> [SwiftFileInfo] {
        var swiftFiles: [SwiftFileInfo] = []
        
        let directoryURL = URL(fileURLWithPath: projectPath)
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey, .pathKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw DocumentationError.cannotEnumerateDirectory(projectPath)
        }
        
        // Convert to array first to avoid async iteration issues
        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
        
        for fileURL in allURLs {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            guard resourceValues.isRegularFile == true,
                  fileURL.pathExtension == "swift" else { continue }
            
            // Skip build artifacts and dependencies
            let path = fileURL.path
            if path.contains("/.build/") || path.contains("/DerivedData/") {
                continue
            }
            
            let content = try String(contentsOf: fileURL)
            let info = try await analyzeSwiftFile(url: fileURL, content: content)
            swiftFiles.append(info)
        }
        
        return swiftFiles
    }
    
    private func analyzeSwiftFile(url: URL, content: String) async throws -> SwiftFileInfo {
        let lines = content.components(separatedBy: .newlines)
        
        var info = SwiftFileInfo(
            url: url,
            relativePath: url.lastPathComponent,
            lineCount: lines.count
        )
        
        // Extract key information using simple pattern matching
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Public classes/structs/actors
            if trimmed.hasPrefix("public class ") || 
               trimmed.hasPrefix("public struct ") || 
               trimmed.hasPrefix("public actor ") {
                let className = extractClassName(from: trimmed)
                info.publicClasses.append(className)
            }
            
            // Public functions
            if trimmed.hasPrefix("public func ") {
                let functionName = extractFunctionName(from: trimmed)
                info.publicFunctions.append(functionName)
            }
            
            // Documentation comments
            if trimmed.hasPrefix("///") {
                info.documentationLines.append(DocComment(
                    lineNumber: index + 1,
                    content: trimmed
                ))
            }
            
            // Import statements
            if trimmed.hasPrefix("import ") {
                let module = String(trimmed.dropFirst(7))
                info.imports.append(module)
            }
        }
        
        return info
    }
    
    // MARK: - Documentation Generation
    
    private func generateAPIDocumentation(swiftFiles: [SwiftFileInfo]) async throws -> [APIDocumentation] {
        var apiDocs: [APIDocumentation] = []
        
        for file in swiftFiles {
            let doc = APIDocumentation(
                fileName: file.relativePath,
                moduleName: extractModuleName(from: file.relativePath),
                classes: file.publicClasses,
                functions: file.publicFunctions,
                documentation: file.documentationLines.map { $0.content },
                imports: file.imports
            )
            apiDocs.append(doc)
        }
        
        return apiDocs
    }
    
    private func generateArchitectureDocumentation(projectPath: String) async throws -> [ArchitectureDocumentation] {
        logger.debug("Generating architecture documentation")
        
        // Analyze project structure
        let structure = try await analyzeProjectStructure(projectPath: projectPath)
        
        let archDoc = ArchitectureDocumentation(
            overview: generateArchitectureOverview(structure: structure),
            components: structure.modules.map { module in
                ComponentDocumentation(
                    name: module.name,
                    purpose: generateComponentPurpose(module: module),
                    dependencies: module.dependencies,
                    files: module.files
                )
            },
            dataFlow: generateDataFlowDiagram(structure: structure)
        )
        
        return [archDoc]
    }
    
    private func generateMCPToolDocumentation(projectPath: String) async throws -> [MCPToolDocumentation] {
        // This would scan for MCP tool definitions and generate documentation
        logger.debug("Generating MCP tool documentation")
        
        // For now, return placeholder documentation
        return [
            MCPToolDocumentation(
                toolName: "xcode_build",
                description: "Enhanced Xcode build tool with intelligent error analysis",
                parameters: [
                    "projectPath": "Path to the Xcode project (.xcodeproj)",
                    "scheme": "Build scheme name",
                    "configuration": "Build configuration (Debug/Release)"
                ],
                examples: [
                    MCPToolExample(
                        title: "Build iOS App",
                        request: #"{"name":"xcode_build","arguments":{"projectPath":"/path/to/app.xcodeproj","scheme":"MyApp"}}"#,
                        description: "Build an iOS app with intelligent analysis"
                    )
                ]
            )
        ]
    }
    
    // MARK: - File Writing
    
    private func writeDocumentationFiles(
        apiDocs: [APIDocumentation],
        architectureDocs: [ArchitectureDocumentation],
        toolDocs: [MCPToolDocumentation],
        outputPath: String
    ) async throws {
        
        // Write API documentation
        let apiMarkdown = generateAPIMarkdown(apiDocs: apiDocs)
        try await writeFile(content: apiMarkdown, path: "\(outputPath)/API_Reference.md")
        
        // Write architecture documentation  
        let archMarkdown = generateArchitectureMarkdown(architectureDocs: architectureDocs)
        try await writeFile(content: archMarkdown, path: "\(outputPath)/Architecture_Generated.md")
        
        // Write tool documentation
        let toolMarkdown = generateToolMarkdown(toolDocs: toolDocs)
        try await writeFile(content: toolMarkdown, path: "\(outputPath)/MCP_Tools_Reference.md")
        
        // Generate index file
        let indexMarkdown = generateIndexMarkdown()
        try await writeFile(content: indexMarkdown, path: "\(outputPath)/README.md")
    }
    
    // MARK: - Helper Methods
    
    private func createOutputDirectory(_ path: String) throws {
        try fileManager.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func writeFile(content: String, path: String) async throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        logger.debug("📝 Generated documentation: \(path)")
    }
    
    private func extractClassName(from line: String) -> String {
        // Simple regex alternative for class name extraction
        let components = line.components(separatedBy: " ")
        if let classIndex = components.firstIndex(of: "class") ?? 
                            components.firstIndex(of: "struct") ?? 
                            components.firstIndex(of: "actor"),
           classIndex + 1 < components.count {
            let name = components[classIndex + 1]
            return name.components(separatedBy: ":").first ?? name
        }
        return "Unknown"
    }
    
    private func extractFunctionName(from line: String) -> String {
        // Extract function name from "public func functionName(...)"
        let components = line.components(separatedBy: " ")
        if let funcIndex = components.firstIndex(of: "func"),
           funcIndex + 1 < components.count {
            let name = components[funcIndex + 1]
            return name.components(separatedBy: "(").first ?? name
        }
        return "unknown"
    }
    
    private func extractModuleName(from fileName: String) -> String {
        // Extract module name from file path
        let components = fileName.components(separatedBy: "/")
        if let sourcesIndex = components.firstIndex(of: "Sources"),
           sourcesIndex + 1 < components.count {
            return components[sourcesIndex + 1]
        }
        return "Unknown"
    }
    
    // MARK: - Markdown Generation
    
    private func generateAPIMarkdown(apiDocs: [APIDocumentation]) -> String {
        var markdown = "# API Reference\n\n"
        markdown += "*Auto-generated on \(Date().formatted())*\n\n"
        
        let groupedByModule = Dictionary(grouping: apiDocs) { $0.moduleName }
        
        for (module, docs) in groupedByModule.sorted(by: { $0.key < $1.key }) {
            markdown += "## \(module)\n\n"
            
            for doc in docs {
                markdown += "### \(doc.fileName)\n\n"
                
                if !doc.classes.isEmpty {
                    markdown += "**Classes/Structs/Actors:**\n"
                    for className in doc.classes {
                        markdown += "- `\(className)`\n"
                    }
                    markdown += "\n"
                }
                
                if !doc.functions.isEmpty {
                    markdown += "**Public Functions:**\n"
                    for function in doc.functions {
                        markdown += "- `\(function)`\n"
                    }
                    markdown += "\n"
                }
                
                if !doc.imports.isEmpty {
                    markdown += "**Dependencies:**\n"
                    for importModule in doc.imports {
                        markdown += "- `\(importModule)`\n"
                    }
                    markdown += "\n"
                }
            }
        }
        
        return markdown
    }
    
    private func generateArchitectureMarkdown(architectureDocs: [ArchitectureDocumentation]) -> String {
        var markdown = "# Architecture Documentation\n\n"
        markdown += "*Auto-generated on \(Date().formatted())*\n\n"
        
        for doc in architectureDocs {
            markdown += doc.overview + "\n\n"
            
            markdown += "## Components\n\n"
            for component in doc.components {
                markdown += "### \(component.name)\n\n"
                markdown += "\(component.purpose)\n\n"
                
                if !component.dependencies.isEmpty {
                    markdown += "**Dependencies:**\n"
                    for dep in component.dependencies {
                        markdown += "- \(dep)\n"
                    }
                    markdown += "\n"
                }
            }
            
            markdown += "## Data Flow\n\n"
            markdown += doc.dataFlow + "\n\n"
        }
        
        return markdown
    }
    
    private func generateToolMarkdown(toolDocs: [MCPToolDocumentation]) -> String {
        var markdown = "# MCP Tools Reference\n\n"
        markdown += "*Auto-generated on \(Date().formatted())*\n\n"
        
        for tool in toolDocs {
            markdown += "## \(tool.toolName)\n\n"
            markdown += "\(tool.description)\n\n"
            
            markdown += "### Parameters\n\n"
            for (param, description) in tool.parameters {
                markdown += "- **\(param)**: \(description)\n"
            }
            markdown += "\n"
            
            markdown += "### Examples\n\n"
            for example in tool.examples {
                markdown += "#### \(example.title)\n\n"
                markdown += "\(example.description)\n\n"
                markdown += "```json\n\(example.request)\n```\n\n"
            }
        }
        
        return markdown
    }
    
    private func generateIndexMarkdown() -> String {
        return """
        # Generated Documentation
        
        *Auto-generated on \(Date().formatted())*
        
        This directory contains automatically generated documentation for the Swift iOS Automation Platform.
        
        ## Contents
        
        - [API Reference](API_Reference.md) - Complete API documentation
        - [Architecture](Architecture_Generated.md) - System architecture overview  
        - [MCP Tools](MCP_Tools_Reference.md) - MCP tool reference
        
        ## Generation
        
        This documentation is automatically generated from the source code using the `DocGenerator` system.
        To regenerate, use the `visual_documentation` MCP tool.
        """
    }
    
    // MARK: - Architecture Analysis
    
    private func analyzeProjectStructure(projectPath: String) async throws -> ProjectStructure {
        // Simplified project structure analysis
        let modules = [
            ProjectModule(
                name: "AutomationCore",
                files: ["XcodeAutomationMCPServer.swift", "EnhancedToolHandlers.swift"],
                dependencies: ["SwiftMCP", "Logging"]
            ),
            ProjectModule(
                name: "XcodeAutomationServer", 
                files: ["main.swift"],
                dependencies: ["AutomationCore"]
            )
        ]
        
        return ProjectStructure(modules: modules)
    }
    
    private func generateArchitectureOverview(structure: ProjectStructure) -> String {
        return """
        # Swift iOS Automation Platform Architecture
        
        The platform is built with a modular architecture focused on performance, security, and extensibility.
        
        ## Core Principles
        - **Zero Network Exposure**: Stdio transport only
        - **Mac Studio M2 Max Optimized**: 85-90% resource utilization
        - **Real-time Intelligence**: File monitoring and change analysis
        - **App Sandbox Compliant**: Complete security framework
        """
    }
    
    private func generateComponentPurpose(module: ProjectModule) -> String {
        switch module.name {
        case "AutomationCore":
            return "Core automation engine with MCP server, tool handlers, and intelligence systems"
        case "XcodeAutomationServer":
            return "Server entry point and configuration management"
        default:
            return "Module providing specialized functionality for the automation platform"
        }
    }
    
    private func generateDataFlowDiagram(structure: ProjectStructure) -> String {
        return """
        ```
        [Client] <-> [MCP Protocol] <-> [Tool Handlers] <-> [Xcode/Simulator]
                                              |
                                    [File Monitor] <-> [Build Intelligence]
        ```
        
        Data flows through the MCP protocol layer to specialized tool handlers that interact with 
        Xcode and iOS simulators while maintaining real-time file monitoring and build intelligence.
        """
    }
    
    private func generateToolDocumentationSection(tool: RegisteredTool) async throws -> String {
        return """
        ## \(tool.definition.name)
        
        \(tool.definition.description)
        
        ### Parameters
        
        ```json
        \(try JSONEncoder().encode(tool.definition.inputSchema))
        ```
        
        ### Usage Example
        
        ```json
        {
          "name": "\(tool.definition.name)",
          "arguments": {
            // Tool-specific arguments
          }
        }
        ```
        
        ---
        
        """
    }
}

// MARK: - Supporting Types

public struct DocumentationResult: Sendable {
    public let apiDocsCount: Int
    public let architectureDocsCount: Int
    public let toolDocsCount: Int
    public let generationTime: Duration
    public let outputPath: String
}

public struct SwiftFileInfo {
    public let url: URL
    public let relativePath: String
    public let lineCount: Int
    public var publicClasses: [String] = []
    public var publicFunctions: [String] = []
    public var documentationLines: [DocComment] = []
    public var imports: [String] = []
}

public struct DocComment {
    public let lineNumber: Int
    public let content: String
}

public struct APIDocumentation {
    public let fileName: String
    public let moduleName: String
    public let classes: [String]
    public let functions: [String]
    public let documentation: [String]
    public let imports: [String]
}

public struct ArchitectureDocumentation {
    public let overview: String
    public let components: [ComponentDocumentation]
    public let dataFlow: String
}

public struct ComponentDocumentation {
    public let name: String
    public let purpose: String
    public let dependencies: [String]
    public let files: [String]
}

public struct MCPToolDocumentation {
    public let toolName: String
    public let description: String
    public let parameters: [String: String]
    public let examples: [MCPToolExample]
}

public struct MCPToolExample {
    public let title: String
    public let request: String
    public let description: String
}

public struct ProjectStructure {
    public let modules: [ProjectModule]
}

public struct ProjectModule {
    public let name: String
    public let files: [String]
    public let dependencies: [String]
}

public enum DocumentationError: Error {
    case cannotEnumerateDirectory(String)
    case invalidSwiftFile(String)
    case outputPathNotWritable(String)
} 