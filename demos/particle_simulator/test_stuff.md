we want our demo (  ) to match the features in @particle_sim.html 
the goal is to have a reusable webgpu FFI library and we are testing that with the demo.

use ```cd demos/particle_simulator; zig build test_browser``` to see how it runs and browser output (we are on PC so use powershell syntax) - you may clean up the debug messages to have a cleaner output if you'd like. you may also edit @test_browser.js if you NEED to

dont forget to update @current_progress.md if you deem it relevant.

currently we get this in the browser