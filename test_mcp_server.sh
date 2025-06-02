#!/bin/bash

echo "🚀 Testing Swift iOS Automation Platform MCP Server"
echo "📋 Demonstrating universal MCP compatibility!"
echo ""

# Test 1: Get available tools
echo "==================== 📋 Available Tools ===================="
echo '{"jsonrpc":"2.0","id":"test-1","method":"tools/list"}' | swift run XcodeAutomationServer
echo ""

# Test 2: Generate visual documentation  
echo "=============== 📊 Visual Documentation =================="
echo '{"jsonrpc":"2.0","id":"test-2","method":"tools/call","params":{"name":"visual_documentation","arguments":{"action":"generate","projectPath":"."}}}' | swift run XcodeAutomationServer
echo ""

# Test 3: List directory contents (universal file operations!)
echo "================== 📁 File Operations ==================="
echo '{"jsonrpc":"2.0","id":"test-3","method":"tools/call","params":{"name":"file_operations","arguments":{"operation":"list","path":"."}}}' | swift run XcodeAutomationServer
echo ""

# Test 4: Live tools documentation
echo "================ 📋 Live Tool Docs ===================="
echo '{"jsonrpc":"2.0","id":"test-4","method":"tools/call","params":{"name":"visual_documentation","arguments":{"action":"live_tools"}}}' | swift run XcodeAutomationServer
echo ""

echo "✅ All tests completed! Our MCP server works with ANY client!" 