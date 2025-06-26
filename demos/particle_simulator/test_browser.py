#!/usr/bin/env python3
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
            'google-chrome',
            'google-chrome-stable', 
            'chromium-browser',
            'msedge',  # Microsoft Edge
            '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe',  # WSL Chrome
            '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'  # WSL Edge
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
            print("❌ No suitable browser found. Install Chrome or Edge.")
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