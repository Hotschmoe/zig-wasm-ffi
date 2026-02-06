// UI and Input Handling for Particle Life Demo

export class UI {
    constructor(wasmInstance, canvas) {
        this.wasm = wasmInstance;
        this.canvas = canvas;
        this.exports = wasmInstance.exports;
        this.paused = false;
        this.lastMouseX = 0;
        this.lastMouseY = 0;

        this.setupCanvasInput();
        this.setupUIControls();
        this.setupKeyboardShortcuts();
        this.syncInitialControls();
    }

    setupCanvasInput() {
        const canvas = this.canvas;

        // Pan via middle-click or right-click drag
        canvas.addEventListener('mousemove', (e) => {
            const dpr = window.devicePixelRatio || 1;
            if ((e.buttons & 4) || (e.buttons & 2)) {
                if (this.exports.setPan) {
                    this.exports.setPan(e.movementX * dpr, e.movementY * dpr);
                }
            }
        });

        // Left/right click attract/repel
        canvas.addEventListener('mousedown', (e) => {
            if (e.button === 0 && this.exports.setMouseDown) this.exports.setMouseDown(true);
            if (e.button === 2 && this.exports.setMouseRightDown) this.exports.setMouseRightDown(true);
        });

        canvas.addEventListener('mouseup', (e) => {
            if (e.button === 0 && this.exports.setMouseDown) this.exports.setMouseDown(false);
            if (e.button === 2 && this.exports.setMouseRightDown) this.exports.setMouseRightDown(false);
        });

        canvas.addEventListener('contextmenu', (e) => e.preventDefault());

        // Zoom
        canvas.addEventListener('wheel', (e) => {
            e.preventDefault();
            if (this.exports.setZoom) this.exports.setZoom(e.deltaY);
        }, { passive: false });

        // Touch support
        canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            if (e.touches.length > 0 && this.exports.setMouseDown) {
                this.exports.setMouseDown(true);
            }
        }, { passive: false });

        canvas.addEventListener('touchend', (e) => {
            e.preventDefault();
            if (this.exports.setMouseDown) this.exports.setMouseDown(false);
        });

        canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
        }, { passive: false });
    }

    setupUIControls() {
        // Particle Count (power of 2 slider)
        const particleCountSlider = document.getElementById('particleCountSlider');
        const particleCountText = document.getElementById('particleCountText');
        if (particleCountSlider) {
            particleCountSlider.addEventListener('input', (e) => {
                const val = Math.round(Math.pow(2, parseFloat(e.target.value)));
                if (particleCountText) particleCountText.innerText = `${val} particles`;
                if (this.exports.setParticleCount) this.exports.setParticleCount(val);
            });
        }

        // Species Count
        const speciesCountSlider = document.getElementById('speciesCountSlider');
        const speciesCountText = document.getElementById('speciesCountText');
        if (speciesCountSlider) {
            speciesCountSlider.addEventListener('input', (e) => {
                const val = parseInt(e.target.value);
                if (speciesCountText) speciesCountText.innerText = `${val} particle types`;
                if (this.exports.setSpeciesCount) this.exports.setSpeciesCount(val);
            });
        }

        // Simulation Width
        const simWidthSlider = document.getElementById('simulationWidthSlider');
        const simWidthText = document.getElementById('simulationWidthText');
        if (simWidthSlider) {
            simWidthSlider.addEventListener('input', (e) => {
                const val = parseInt(e.target.value) * 64;
                if (simWidthText) simWidthText.innerText = `Width: ${val}`;
                this.updateSimulationSize();
            });
        }

        // Simulation Height
        const simHeightSlider = document.getElementById('simulationHeightSlider');
        const simHeightText = document.getElementById('simulationHeightText');
        if (simHeightSlider) {
            simHeightSlider.addEventListener('input', (e) => {
                const val = parseInt(e.target.value) * 64;
                if (simHeightText) simHeightText.innerText = `Height: ${val}`;
                this.updateSimulationSize();
            });
        }

        // Friction
        const frictionSlider = document.getElementById('frictionSlider');
        const frictionText = document.getElementById('frictionText');
        if (frictionSlider) {
            frictionSlider.addEventListener('input', (e) => {
                const val = parseFloat(e.target.value);
                if (frictionText) frictionText.innerText = `Friction: ${val}`;
                if (this.exports.setSimOption) this.exports.setSimOption(0, val);
            });
        }

        // Central Force
        const centralForceSlider = document.getElementById('centralForceSlider');
        const centralForceText = document.getElementById('centralForceText');
        if (centralForceSlider) {
            centralForceSlider.addEventListener('input', (e) => {
                const val = parseFloat(e.target.value) / 10.0;
                if (centralForceText) centralForceText.innerText = `Central force: ${val.toFixed(1)}`;
                if (this.exports.setSimOption) this.exports.setSimOption(4, val);
            });
        }

        // Symmetric Forces
        const symmetricForces = document.getElementById('symmetricForces');
        if (symmetricForces) {
            symmetricForces.addEventListener('change', (e) => {
                if (this.exports.setSimOption) this.exports.setSimOption(5, e.target.checked ? 1.0 : 0.0);
            });
        }

        // Looping Borders
        const loopingBorders = document.getElementById('loopingBorders');
        if (loopingBorders) {
            loopingBorders.addEventListener('change', (e) => {
                if (this.exports.setSimOption) this.exports.setSimOption(3, e.target.checked ? 1.0 : 0.0);
            });
        }

        // Buttons
        document.getElementById('toggleSettingsButton')?.addEventListener('click', () => this.toggleSettings());
        document.getElementById('pauseButton')?.addEventListener('click', () => this.togglePause());
        document.getElementById('centerViewButton')?.addEventListener('click', () => {
            if (this.exports.centerView) this.exports.centerView();
        });
        document.getElementById('restartButton')?.addEventListener('click', () => {
            if (this.exports.restart) this.exports.restart();
        });
        document.getElementById('randomizeButton')?.addEventListener('click', () => {
            if (this.exports.randomize) this.exports.randomize();
        });
        document.getElementById('copyUrlButton')?.addEventListener('click', () => this.copyUrl());
        document.getElementById('fullscreenButton')?.addEventListener('click', () => this.toggleFullscreen());
    }

    syncInitialControls() {
        const fireInput = (id, type = 'input') => {
            const el = document.getElementById(id);
            if (el) el.dispatchEvent(new Event(type));
        };
        fireInput('particleCountSlider');
        fireInput('speciesCountSlider');
        this.updateSimulationSize();
        fireInput('frictionSlider');
        fireInput('centralForceSlider');
        fireInput('loopingBorders', 'change');
        fireInput('symmetricForces', 'change');
    }

    setupKeyboardShortcuts() {
        window.addEventListener('keydown', (e) => {
            if (e.key === ' ') { this.togglePause(); e.preventDefault(); }
            if (e.key === 'c') { if (this.exports.centerView) this.exports.centerView(); e.preventDefault(); }
            if (e.key === 's') { this.toggleSettings(); e.preventDefault(); }
        });
    }

    updateSimulationSize() {
        const w = Number(document.getElementById('simulationWidthSlider')?.value ?? 16) * 64;
        const h = Number(document.getElementById('simulationHeightSlider')?.value ?? 16) * 64;
        if (this.exports.setSimulationSize) this.exports.setSimulationSize(w, h);
    }

    togglePause() {
        this.paused = !this.paused;
        const btn = document.getElementById('pauseButton');
        if (btn) btn.innerText = this.paused ? "Continue" : "Pause";
    }

    toggleSettings() {
        const panel = document.getElementById('toolsPanel');
        if (panel) {
            const isHidden = panel.style.opacity === '0' || panel.style.visibility === 'hidden';
            panel.style.opacity = isHidden ? '1' : '0';
            panel.style.visibility = isHidden ? 'visible' : 'hidden';
        }
    }

    toggleFullscreen() {
        if (!document.fullscreenElement) {
            document.body.requestFullscreen().catch(() => {});
            const btn = document.getElementById('fullscreenButton');
            if (btn) btn.innerText = "Exit Fullscreen";
        } else {
            document.exitFullscreen();
            const btn = document.getElementById('fullscreenButton');
            if (btn) btn.innerText = "Fullscreen";
        }
    }

    copyUrl() {
        alert("URL copying not yet implemented");
    }

    isPaused() {
        return this.paused;
    }
}
