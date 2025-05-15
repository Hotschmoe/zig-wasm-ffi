const webaudio = @import("zig-wasm-ffi").webaudio;

// FFI import for JavaScript's console.log
extern "env" fn js_log_string(message_ptr: [*c]const u8, message_len: u32) void;

// Helper function to log strings from Zig
fn log_audio_handler(message: []const u8) void {
    const prefix = "[AudioH] ";
    var buffer: [128]u8 = undefined;
    var i: usize = 0;
    while (i < prefix.len and i < buffer.len) : (i += 1) {
        buffer[i] = prefix[i];
    }
    var j: usize = 0;
    while (j < message.len and (i + j) < buffer.len - 1) : (j += 1) {
        buffer[i + j] = message[j];
    }
    const final_len = i + j;
    js_log_string(&buffer, @intCast(final_len));
}

var g_audio_context: ?webaudio.AudioContextHandle = null;

const EXPLODE_SOUND_REQUEST_ID: u32 = 1;
var explode_sound_requested: bool = false;

// Embed the sound file.
// IMPORTANT: User must create 'demos/webinput_demo/assets/explode.ogg'
const explode_ogg_bytes = @embedFile("assets/explode.ogg");

// Background Music Assets & State
const BACKGROUND_MUSIC_REQUEST_ID: u32 = 2;
const BACKGROUND_MUSIC_TAG: u32 = 1; // Unique tag for the background music instance
const background_ogg_bytes = @embedFile("assets/background.ogg");
var background_music_js_buffer_id: ?u32 = null;
var background_music_decode_requested: bool = false;
var is_background_music_playing: bool = false;

pub fn init_audio_system() void {
    log_audio_handler("Initializing audio system...");
    webaudio.init_webaudio_module_state(); // Good practice, especially for testing/re-runs

    g_audio_context = webaudio.createAudioContext() orelse {
        log_audio_handler("Failed to create AudioContext.");
        return;
    };
    log_audio_handler("AudioContext created successfully.");

    switch (webaudio.getAudioContextState()) {
        .Ready => log_audio_handler("AudioContext state: Ready"),
        else => log_audio_handler("AudioContext state: Unexpected after creation!"),
    }

    // Request decoding for background music
    log_audio_handler("Requesting background music decoding...");
    if (webaudio.requestDecodeAudioData(g_audio_context.?, background_ogg_bytes, BACKGROUND_MUSIC_REQUEST_ID)) {
        log_audio_handler("Background music decode request submitted.");
        background_music_decode_requested = true;
    } else {
        log_audio_handler("Failed to submit background music decode request.");
    }
}

pub fn trigger_explosion_sound() void {
    if (g_audio_context == null) {
        log_audio_handler("Cannot trigger explosion: AudioContext not initialized.");
        return;
    }
    if (explode_sound_requested) {
        // Optional: Debounce or allow re-triggering by resetting status first
        log_audio_handler("Explosion sound already requested and pending/processed.");
        // To allow re-triggering, you might call webaudio.releaseDecodeRequest(EXPLODE_SOUND_REQUEST_ID) here
        // and reset explode_sound_requested = false, if the previous one finished or errored.
        // For now, just prevent re-request if already active.
        // Check current status before deciding to re-request
        const maybe_status = webaudio.getDecodeRequestStatus(EXPLODE_SOUND_REQUEST_ID);
        if (maybe_status) |status| {
            switch (status) {
                .Pending => {
                    log_audio_handler("Explosion sound still pending, not re-triggering.");
                    return;
                },
                .Success, .Error, .Free => {
                    log_audio_handler("Previous explosion sound not pending (status known), allowing new trigger.");
                    webaudio.releaseDecodeRequest(EXPLODE_SOUND_REQUEST_ID); // Clear previous slot
                    explode_sound_requested = false; // Allow new request
                },
            }
        } else { // status was null
            log_audio_handler("Previous explosion sound not pending (status null), allowing new trigger.");
            webaudio.releaseDecodeRequest(EXPLODE_SOUND_REQUEST_ID); // Clear previous slot if it makes sense for null
            explode_sound_requested = false; // Allow new request
        }
    }

    log_audio_handler("Triggering explosion sound (requesting decode)...");
    if (webaudio.requestDecodeAudioData(g_audio_context.?, explode_ogg_bytes, EXPLODE_SOUND_REQUEST_ID)) {
        log_audio_handler("Explosion sound decode request submitted.");
        explode_sound_requested = true;
    } else {
        log_audio_handler("Failed to submit explosion sound decode request.");
        explode_sound_requested = false; // Ensure it can be tried again if submission failed
    }
}

pub fn process_audio_events() void {
    // Process explosion sound
    if (explode_sound_requested or webaudio.getDecodeRequestStatus(EXPLODE_SOUND_REQUEST_ID) != null) { // Check if there's any status to process
        const maybe_status = webaudio.getDecodeRequestStatus(EXPLODE_SOUND_REQUEST_ID);
        if (maybe_status) |status| {
            switch (status) {
                .Pending => {}, // Was: .Pending => { /* log_audio_handler("Explosion sound decoding: Pending..."); */ }, // Can be noisy
                .Success => {
                    log_audio_handler("Explosion sound decoding: Success!");
                    if (webaudio.getDecodedAudioBufferInfo(EXPLODE_SOUND_REQUEST_ID)) |info| {
                        log_audio_handler("Audio decoded. Buffer info available.");
                        _ = info.js_buffer_id;
                        _ = info.duration_ms;
                        _ = info.length_samples;
                        _ = info.num_channels;
                        _ = info.sample_rate_hz;
                        log_audio_handler("  Info: js_buffer_id, duration_ms, length_samples, num_channels, sample_rate_hz processed.");

                        // Play the sound!
                        if (g_audio_context) |ctx_handle| {
                            log_audio_handler("Attempting to play sound...");
                            webaudio.playDecodedAudio(ctx_handle, info.js_buffer_id);
                        } else {
                            log_audio_handler("Cannot play sound: AudioContext handle is null.");
                        }
                    } else {
                        log_audio_handler("Audio decoded, but no buffer info retrieved.");
                    }
                    webaudio.releaseDecodeRequest(EXPLODE_SOUND_REQUEST_ID);
                    log_audio_handler("Explosion sound decode request released.");
                    explode_sound_requested = false; // Ready for a new request
                },
                .Error => {
                    log_audio_handler("Explosion sound decoding: Error!");
                    webaudio.releaseDecodeRequest(EXPLODE_SOUND_REQUEST_ID);
                    log_audio_handler("Explosion sound decode request released after error.");
                    explode_sound_requested = false; // Ready for a new request
                },
                .Free => {
                    if (explode_sound_requested) {
                        log_audio_handler("Explosion sound request was active but now slot is Free. Resetting.");
                        explode_sound_requested = false;
                    }
                },
            }
        } else { // status was null
            if (explode_sound_requested) {
                log_audio_handler("Explosion sound request was active but now ID not found (status null). Resetting.");
                explode_sound_requested = false;
            }
        }
    }

    // Process background music decoding
    if (background_music_decode_requested and webaudio.getDecodeRequestStatus(BACKGROUND_MUSIC_REQUEST_ID) != null) {
        const maybe_bg_status = webaudio.getDecodeRequestStatus(BACKGROUND_MUSIC_REQUEST_ID);
        if (maybe_bg_status) |status| {
            switch (status) {
                .Pending => {},
                .Success => {
                    log_audio_handler("Background music decoding: Success!");
                    if (webaudio.getDecodedAudioBufferInfo(BACKGROUND_MUSIC_REQUEST_ID)) |info| {
                        background_music_js_buffer_id = info.js_buffer_id;
                        log_audio_handler("Background music buffer info stored.");
                        // Optionally log more info like duration etc.
                    } else {
                        log_audio_handler("Background music decoded, but no buffer info retrieved.");
                    }
                    webaudio.releaseDecodeRequest(BACKGROUND_MUSIC_REQUEST_ID); // Release slot, buffer info is stored
                    background_music_decode_requested = false;
                    log_audio_handler("Background music decode request released.");
                },
                .Error => {
                    log_audio_handler("Background music decoding: Error!");
                    webaudio.releaseDecodeRequest(BACKGROUND_MUSIC_REQUEST_ID);
                    background_music_decode_requested = false;
                },
                .Free => { // Should not happen if we requested and are waiting
                    if (background_music_decode_requested) {
                        log_audio_handler("Background music request was active but now slot is Free. Resetting.");
                        background_music_decode_requested = false;
                    }
                },
            }
        } else { // status was null
            if (background_music_decode_requested) {
                log_audio_handler("Background music request was active but now ID not found (status null). Resetting.");
                background_music_decode_requested = false;
            }
        }
    }
}

pub fn trigger_toggle_background_music() void {
    if (g_audio_context == null) {
        log_audio_handler("Cannot toggle background music: AudioContext not initialized.");
        return;
    }

    if (is_background_music_playing) {
        log_audio_handler("Pausing background music...");
        webaudio.stopTaggedSound(g_audio_context.?, BACKGROUND_MUSIC_TAG);
        is_background_music_playing = false;
        log_audio_handler("Background music paused.");
    } else {
        if (background_music_js_buffer_id) |js_id| {
            log_audio_handler("Playing background music (looping)...");
            webaudio.playLoopingTaggedSound(g_audio_context.?, js_id, BACKGROUND_MUSIC_TAG);
            is_background_music_playing = true;
            log_audio_handler("Background music playing.");
        } else {
            log_audio_handler("Cannot play background music: Not yet decoded or decode failed.");
            if (!background_music_decode_requested and g_audio_context != null) {
                // Optional: Try to re-request decoding if it failed and we're trying to play
                log_audio_handler("Attempting to re-request background music decoding...");
                if (webaudio.requestDecodeAudioData(g_audio_context.?, background_ogg_bytes, BACKGROUND_MUSIC_REQUEST_ID)) {
                    log_audio_handler("Background music decode re-request submitted.");
                    background_music_decode_requested = true;
                } else {
                    log_audio_handler("Failed to submit background music decode re-request.");
                }
            }
        }
    }
}
