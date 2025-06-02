#!/usr/bin/env python3
"""
Test script for Swift iOS Automation Platform MCP Server
Demonstrates that our MCP server can be used from ANY language/tool!
"""

import json
import subprocess
import sys
import time

def send_mcp_request(method, params=None):
    """Send an MCP request to our Swift server via stdio"""
    request = {
        "jsonrpc": "2.0",
        "id": "test-" + str(int(time.time())),
        "method": method,
        "params": params or {}
    }
    
    request_json = json.dumps(request)
    print(f"📤 Sending: {request_json}")
    
    # Start our Swift MCP server
    process = subprocess.Popen(
        ["swift", "run", "XcodeAutomationServer"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd="/Users/carrington/Apple Dev/MCPXCODE/swift-ios-automation-platform"
    )
    
    # Send request
    stdout, stderr = process.communicate(request_json + "\n")
    
    print(f"📥 Response: {stdout}")
    if stderr:
        print(f"⚠️ Stderr: {stderr}")
    
    return stdout

def test_visual_documentation():
    """Test our new visual documentation tool"""
    print("🧪 Testing Visual Documentation Generation...")
    
    params = {
        "name": "visual_documentation",
        "arguments": {
            "action": "generate",
            "projectPath": ".",
            "outputPath": "Documentation/Generated"
        }
    }
    
    response = send_mcp_request("tools/call", params)
    return response

def test_simulator_list():
    """Test simulator listing (works on any Mac, not just Xcode projects!)"""
    print("🧪 Testing Simulator Control...")
    
    params = {
        "name": "simulator_control", 
        "arguments": {
            "action": "list"
        }
    }
    
    response = send_mcp_request("tools/call", params)
    return response

def test_file_operations():
    """Test file operations (universal file system access!)"""
    print("🧪 Testing File Operations...")
    
    params = {
        "name": "file_operations",
        "arguments": {
            "operation": "list",
            "path": "."
        }
    }
    
    response = send_mcp_request("tools/call", params)
    return response

def test_get_tools():
    """Get list of all available tools"""
    print("🧪 Getting Available Tools...")
    
    response = send_mcp_request("tools/list")
    return response

def main():
    """Run all tests to demonstrate MCP server capabilities"""
    print("🚀 Testing Swift iOS Automation Platform MCP Server")
    print("📋 This demonstrates our server works with ANY client!\n")
    
    tests = [
        ("📋 Available Tools", test_get_tools),
        ("📊 Visual Documentation", test_visual_documentation),
        ("📱 Simulator Control", test_simulator_list),
        ("📁 File Operations", test_file_operations),
    ]
    
    for test_name, test_func in tests:
        print(f"\n" + "="*50)
        print(f"{test_name}")
        print("="*50)
        
        try:
            result = test_func()
            print(f"✅ {test_name} completed")
        except Exception as e:
            print(f"❌ {test_name} failed: {e}")
        
        print()

if __name__ == "__main__":
    main() 