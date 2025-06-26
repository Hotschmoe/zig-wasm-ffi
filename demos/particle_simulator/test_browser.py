#!/usr/bin/env python3

# === PREP: Setup Instructions for Developers ===
#
# This script runs a headless browser test to capture console output from the WebAssembly application.
# 
# REQUIREMENTS:
# 1. Python 3.6+ (should be available if you're running this)
# 2. A supported browser installed:
#
# WINDOWS:
#   - Google Chrome: https://www.google.com/chrome/
#     Install to default location: C:\Program Files\Google\Chrome\Application\chrome.exe
#     OR: C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
#   
#   - Microsoft Edge: Usually pre-installed on Windows 10/11
#     Default location: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
#
# LINUX/WSL:
#   - Install Chrome: sudo apt install google-chrome-stable
#   - OR install Chromium: sudo apt install chromium-browser
#   - OR use WSL with Windows Chrome/Edge (paths included below)
#
# MACOS:
#   - Install Chrome: https://www.google.com/chrome/
#   - Default location: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
#
# TROUBLESHOOTING:
# - If browser not found, install Chrome or Edge from the links above
# - On Windows, make sure Chrome is installed to the default Program Files location
# - On WSL, you can use Windows browsers (paths included in script)
#
# ===============================================================

import subprocess
import time
import sys
import os
import signal

def run_browser_test():
    # Start HTTP server
    print("Starting HTTP server...")
    server = subprocess.Popen(
        ['python', '-m', 'http.server', '8000'],
        cwd='dist',
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    try:
        # Wait for server to start
        time.sleep(2)
        
        # Run headless browser with console output
        print("Running headless browser test...")
        
        # Try different Chrome/Edge executables
        chrome_commands = [
            # Windows paths
            'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
            'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
            'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
            'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
            # Command line shortcuts (if in PATH)
            'chrome',
            'msedge',
            # Linux/Unix paths
            'google-chrome',
            'google-chrome-stable', 
            'chromium-browser',
            # WSL Windows paths
            '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe',
            '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe',
            '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
            '/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe',
            # macOS paths
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        ]
        
        browser_found = False
        for chrome_cmd in chrome_commands:
            try:
                result = subprocess.run([
                    chrome_cmd,
                    '--headless',
                    '--disable-gpu',
                    '--disable-web-security',
                    '--disable-features=VizDisplayCompositor',
                    '--enable-logging',
                    '--log-level=0',
                    '--virtual-time-budget=5000',
                    '--dump-dom',
                    'http://localhost:8000'
                ], capture_output=True, text=True, timeout=15)
                
                print(f"✓ Using browser: {chrome_cmd}")
                print("=== Console Output ===")
                if result.stdout:
                    print(result.stdout)
                if result.stderr:
                    print("=== Debug Info ===")
                    # Filter useful debug info
                    lines = result.stderr.split('\n')
                    for line in lines:
                        if any(keyword in line.lower() for keyword in ['console', 'error', 'warning', 'info']):
                            print(line)
                
                browser_found = True
                break
                
            except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.CalledProcessError):
                continue
        
        if not browser_found:
            print("❌ No suitable browser found.")
            print("Please install Google Chrome or Microsoft Edge.")
            print("See the PREP section at the top of this file for installation instructions.")
            return 1
            
        return 0
        
    finally:
        # Clean up server
        server.terminate()
        try:
            server.wait(timeout=3)
        except subprocess.TimeoutExpired:
            server.kill()

if __name__ == "__main__":
    sys.exit(run_browser_test())