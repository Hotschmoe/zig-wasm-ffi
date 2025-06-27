#!/usr/bin/env node
const puppeteer = require('puppeteer');
const http = require('http');
const fs = require('fs');
const path = require('path');

async function runBrowserTest() {
    // Limit console output to prevent spam
    const MAX_OUTPUT_LINES = 50;
    let outputLineCount = 0;
    let outputLimitReached = false;

    function logWithLimit(logFn, ...args) {
        if (outputLineCount >= MAX_OUTPUT_LINES) {
            if (!outputLimitReached) {
                console.log(`\n⚠️  Output limit reached (${MAX_OUTPUT_LINES} lines). Suppressing further output...`);
                outputLimitReached = true;
            }
            return;
        }
        outputLineCount++;
        logFn(...args);
    }

    // Start simple HTTP server
    const server = http.createServer((req, res) => {
        const filePath = path.join(__dirname, 'dist', req.url === '/' ? 'index.html' : req.url);
        
        if (fs.existsSync(filePath)) {
            const ext = path.extname(filePath);
            const contentType = {
                '.html': 'text/html',
                '.js': 'application/javascript',
                '.wasm': 'application/wasm',
                '.css': 'text/css'
            }[ext] || 'text/plain';
            
            res.setHeader('Content-Type', contentType);
            res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
            res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
            fs.createReadStream(filePath).pipe(res);
        } else {
            res.statusCode = 404;
            res.end('Not found');
        }
    });
    
    server.listen(8000);
    console.log('🚀 Server started on http://localhost:8000');
    
    try {
        const browser = await puppeteer.launch({ headless: 'new' });
        const page = await browser.newPage();
        
        // Capture only important console messages
        page.on('console', msg => {
            const type = msg.type();
            const text = msg.text();
            
            // Filter to show only initialization and important messages
            if (text.includes('Starting particle life simulation') ||
                text.includes('ParticleLifeRenderer.init() completed') ||
                text.includes('Particle life renderer initialized') ||
                text.includes('ERROR') ||
                text.includes('WARN') ||
                type === 'error') {
                logWithLimit(console.log, `[${type.toUpperCase()}] ${text}`);
            }
        });
        
        // Enhanced error capturing with stack traces
        page.on('pageerror', error => {
            logWithLimit(console.error, `❌ Page Error: ${error.message}`);
            logWithLimit(console.error, `Stack: ${error.stack}`);
        });

        // Capture JavaScript errors with stack traces
        await page.evaluateOnNewDocument(() => {
            window.addEventListener('error', (e) => {
                console.error(`JS Error: ${e.error.message} at ${e.filename}:${e.lineno}:${e.colno}`);
                console.error(`Stack: ${e.error.stack}`);
            });
        });

        // Capture more WebGPU specific errors
        await page.evaluate(() => {
            const originalError = console.error;
            console.error = function(...args) {
                // Log the full error context
                originalError.apply(console, ['[DETAILED]', ...args]);
                if (args[0] && args[0].stack) {
                    originalError.apply(console, ['Stack:', args[0].stack]);
                }
            };
        });
        
        // Capture unhandled promise rejections
        page.on('response', response => {
            if (!response.ok()) {
                logWithLimit(console.error, `❌ HTTP Error: ${response.status()} ${response.url()}`);
            }
        });
        
        // Navigate to your WASM app
        await page.goto('http://localhost:8000', { waitUntil: 'networkidle0' });
        
        // Wait for WASM to load and execute - allow more time for initialization
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        // Check if the particle simulation is running
        const isRunning = await page.evaluate(() => {
            return window.wasmInstance !== undefined;
        });
        
        if (isRunning) {
            console.log('✅ Particle Life Simulation is running successfully!');
        } else {
            console.log('❌ Simulation may not be running properly');
        }
        
        await browser.close();
        console.log('✓ Browser test completed');
        
    } catch (error) {
        console.error('Browser test failed:', error);
        process.exit(1);
    } finally {
        server.close();
    }
}

runBrowserTest();