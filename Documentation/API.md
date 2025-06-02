# Swift iOS Automation Platform - API Reference

## 🚀 **MCP Server API**

The Swift iOS Automation Platform exposes its capabilities through the Model Context Protocol (MCP), providing 6 core tools for iOS development automation.

### **Server Information**
- **Name**: Swift iOS Automation Platform
- **Version**: 1.0.0
- **Protocol**: MCP 2024-11-05
- **Transport**: stdio (secure, zero network exposure)

---

## 📱 **Core MCP Tools**

### 1. **xcode_build** - Enhanced Build Operations

Build Xcode projects with intelligent error analysis and performance tracking.

**Parameters:**
```json
{
  "projectPath": "string (required)",
  "scheme": "string (required)",
  "destination": "string (optional, default: 'platform=iOS Simulator,name=iPhone 15')",
  "configuration": "Debug|Release (optional, default: 'Debug')"
}
```

**Enhanced Features:**
- ✅ **Build Intelligence**: Automatic error categorization (Syntax, Dependencies, Type Errors)
- ✅ **Performance Tracking**: Build duration and resource usage monitoring
- ✅ **Smart Suggestions**: Context-aware recommendations for fixing issues
- ✅ **Resource Management**: Optimal utilization of Mac Studio M2 Max capabilities

**Example Response:**
```
✅ Build successful in 23.4 seconds

🧠 Build Intelligence:
  📊 Error Categories: 3
  💡 Suggestions:
    • Consider using incremental builds for faster development
    • Enable parallel compilation in build settings
```

---

### 2. **simulator_control** - Advanced Simulator Management

Control iOS simulators with performance optimization and testing matrix generation.

**Parameters:**
```json
{
  "action": "list|boot|matrix|performance (required)",
  "deviceId": "string (optional, required for 'boot')",
  "appPath": "string (optional, for install/launch actions)"
}
```

**Enhanced Actions:**
- **`list`**: Enhanced simulator listing with status indicators
- **`boot`**: Performance-monitored simulator booting
- **`matrix`**: Generate optimal testing device matrix for current hardware  
- **`performance`**: Real-time simulator performance metrics

**Example Response (matrix):**
```
🎯 Optimal Testing Matrix (Mac Studio M2 Max):

🖥️ Hardware: 12 cores, 32GB RAM
📱 Recommended simulators: 6

💡 Suggested Device Matrix:
  📱 iPhone 15 Pro (iOS 17.0)
  📱 iPhone 14 (iOS 16.0)
  📱 iPad Pro 12.9" (iPadOS 17.0)
  📱 iPhone SE (iOS 16.0)
  📱 iPhone 15 Plus (iOS 17.0)
  📱 iPad Air (iPadOS 16.0)
```

---

### 3. **file_operations** - Intelligent File Management

Secure file operations with codebase analysis and search capabilities.

**Parameters:**
```json
{
  "operation": "analyze|search|dependencies (required)",
  "path": "string (required)",
  "pattern": "string (optional, for search)",
  "recursive": "boolean (optional, default: false)"
}
```

**Enhanced Operations:**
- **`analyze`**: Comprehensive codebase analysis with metrics
- **`search`**: Swift-focused code search with pattern matching
- **`dependencies`**: Package.swift dependency analysis

**Example Response (analyze):**
```
📊 Codebase Analysis:

📄 Swift files: 127
🧪 Test files: 34
📝 Total lines: 15,847
📈 Test coverage: 27%
```

---

### 4. **project_analysis** - Deep Project Intelligence

Advanced project structure and configuration analysis.

**Parameters:**
```json
{
  "projectPath": "string (required)",
  "analysis": "comprehensive|performance|security|dependencies (required)"
}
```

**Analysis Types:**
- **`comprehensive`**: Complete project overview with schemes and structure
- **`performance`**: Build time analysis and optimization recommendations  
- **`security`**: Security best practices audit
- **`dependencies`**: Dependency graph and vulnerability analysis

**Example Response (security):**
```
🔒 Project Security Analysis:

🚨 Security Issues:
  🟡 CocoaPods detected - consider migrating to SPM for better security

✅ Good Practices:
  ✅ Using Swift Package Manager
  ✅ .gitignore present
```

---

### 5. **run_tests** - Intelligent Test Execution

Execute tests with detailed reporting and failure analysis.

**Parameters:**
```json
{
  "projectPath": "string (required)",
  "scheme": "string (required)",
  "destination": "string (optional)",
  "testSuite": "string (optional)",
  "testClass": "string (optional)"
}
```

**Enhanced Features:**
- ✅ **Detailed Reporting**: Pass/fail counts with execution times
- ✅ **Failure Analysis**: Categorized test failures with suggestions
- ✅ **Performance Tracking**: Test execution performance metrics
- ✅ **Smart Filtering**: Target specific test suites or classes

**Example Response:**
```
✅ All tests passed in 45.2 seconds
📊 Results: 127 passed, 0 failed

🎯 Performance: 2.8x faster than baseline
💡 Suggestion: Consider parallel test execution for larger suites
```

---

### 6. **log_monitor** - Real-time Log Intelligence

Monitor iOS simulator and device logs with intelligent filtering.

**Parameters:**
```json
{
  "action": "start|stop|tail|query (required)",
  "deviceId": "string (optional)",
  "filterPredicate": "string (optional)",
  "level": "debug|info|notice|error|fault (optional, default: 'info')"
}
```

**Features:**
- ✅ **Real-time Monitoring**: Live log streaming with intelligent filtering
- ✅ **Smart Categorization**: Automatic log classification and priority
- ✅ **Performance Impact**: Zero-overhead log collection
- ✅ **Search & Filter**: Advanced NSPredicate-based filtering

---

## 🔧 **Advanced Features**

### **File System Monitoring**
Real-time project change detection with intelligent impact analysis:

```swift
// Automatic monitoring setup
startProjectMonitoring(projectPath: "/path/to/project") { change in
    // Smart recommendations based on change type
    if change.impact == .high {
        // Suggest rebuild, dependency updates, etc.
    }
}
```

### **Resource Management**
Dynamic resource allocation optimized for Mac Studio M2 Max:

- **CPU Utilization**: 85-90% optimal usage
- **Memory Management**: Intelligent allocation for simulators
- **Concurrent Operations**: Up to 6 simulators + parallel builds

### **Security Framework**
App Sandbox compliant with user-controlled permissions:

- **Path Validation**: Automatic security validation for all file operations
- **Zero Network**: Stdio transport only, no external connections
- **Sandboxed Execution**: Full App Sandbox compliance

---

## 📊 **Performance Metrics**

### **Target Performance (Mac Studio M2 Max)**
| Operation | Target | Typical | Improvement |
|-----------|--------|---------|-------------|
| Error Detection | <5 seconds | <3 seconds | **18x faster** |
| Simulator Boot | <30 seconds | ~15 seconds | **4x faster** |
| Build Intelligence | <0.5 seconds | ~0.2 seconds | **New capability** |
| Resource Utilization | 85-90% | ~87% | **75% improvement** |

### **System Requirements**
- **macOS**: 14.0+ (recommended: 15.0+)
- **Xcode**: 16.0+
- **Swift**: 6.0+
- **Hardware**: Apple Silicon recommended (optimized for M2 Max)

---

## 🔗 **Integration Examples**

### **Basic MCP Request**
```json
{
  "jsonrpc": "2.0",
  "id": "build-1",
  "method": "tools/call",
  "params": {
    "name": "xcode_build",
    "arguments": {
      "projectPath": "/path/to/MyApp.xcodeproj",
      "scheme": "MyApp",
      "configuration": "Debug"
    }
  }
}
```

### **Enhanced Simulator Matrix**
```json
{
  "jsonrpc": "2.0",
  "id": "sim-matrix",
  "method": "tools/call",
  "params": {
    "name": "simulator_control",
    "arguments": {
      "action": "matrix"
    }
  }
}
```

---

## 🚦 **Error Handling**

### **Standard MCP Errors**
- **-32700**: Parse error (malformed JSON)
- **-32600**: Invalid request 
- **-32601**: Method not found
- **-32602**: Invalid params

### **Platform-Specific Errors**
- **-32000**: Build failed (with detailed analysis)
- **-32001**: Security violation (path validation failed)
- **-32002**: Resource exhausted (system limits reached)

---

## 🎯 **Getting Started**

1. **Start Server**: `swift run XcodeAutomationServer`
2. **Initialize MCP**: Send `initialize` request
3. **List Tools**: Call `tools/list` to see available capabilities
4. **Execute Tools**: Use `tools/call` with specific tool parameters

**Next Steps**: See [Implementation Guide](IMPLEMENTATION_GUIDE.md) for integration examples and [Performance Guide](PERFORMANCE.md) for optimization strategies.
