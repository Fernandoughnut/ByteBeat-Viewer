use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Mutex;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use flutter_rust_bridge::frb;
use rodio::{OutputStream, Sink, Source};

/// Classic bytebeat rate. Try 11025, 22050 or 44100 for a higher pitch.
const SAMPLE_RATE: u32 = 8000;

// Shared state between the Flutter UI thread and the audio thread.
static FORMULA: AtomicU32 = AtomicU32::new(0);
static PARAM_A: AtomicU32 = AtomicU32::new(8);
static PARAM_B: AtomicU32 = AtomicU32::new(12);
static POSITION: AtomicU32 = AtomicU32::new(0); // current t
static RUNNING: AtomicBool = AtomicBool::new(false);
static AUDIO_THREAD: Mutex<Option<JoinHandle<()>>> = Mutex::new(None);

/// Render `len` bytebeat samples starting at time `start`.
/// `formula` picks the expression; `a` and `b` are tweakable parameters.
/// Runs synchronously: it is fast enough for a few thousand samples per call.
#[frb(sync)]
pub fn render_bytebeat(formula: u32, start: u32, len: u32, a: u32, b: u32) -> Vec<u8> {
    (start..start.wrapping_add(len))
        .map(|t| sample(formula, t, a, b))
        .collect()
}

/// Names shown in the Flutter dropdown. Add a formula here and in `sample`.
#[frb(sync)]
pub fn formula_names() -> Vec<String> {
    vec![
        "Classic melody".to_string(),
        "Sierpinski-ish".to_string(),
        "Shift mix".to_string(),
        "Saw stack".to_string(),
    ]
}

fn sample(formula: u32, t: u32, a: u32, b: u32) -> u8 {
    // wrapping_* avoids overflow panics in debug builds.
    let v: u32 = match formula {
        0 => t.wrapping_mul(((t >> 12) | (t >> 8)) & 63 & t.wrapping_shr(a)),
        1 => (t & t.wrapping_shr(a)) | t.wrapping_shr(b),
        2 => (t.wrapping_shr(a) | t).wrapping_mul(b.max(1)),
        3 => t.wrapping_mul(a.max(1)) & t.wrapping_shr(b),
        _ => 0,
    };
    (v & 0xFF) as u8
}

// ---------------------------------------------------------------------------
// Audio
// ---------------------------------------------------------------------------

/// An endless audio source that asks `sample()` for each value as the sound
/// card needs it. It reads the shared atomics every sample, so changing the
/// formula or sliders is heard immediately.
struct ByteBeatSource;

impl Iterator for ByteBeatSource {
    type Item = f32;

    fn next(&mut self) -> Option<f32> {
        if !RUNNING.load(Ordering::Relaxed) {
            return None; // ends the stream; the audio thread then exits
        }
        let t = POSITION.fetch_add(1, Ordering::Relaxed);
        let s = sample(
            FORMULA.load(Ordering::Relaxed),
            t,
            PARAM_A.load(Ordering::Relaxed),
            PARAM_B.load(Ordering::Relaxed),
        );
        // Map 0..=255 to -1.0..=1.0
        Some(s as f32 / 127.5 - 1.0)
    }
}

impl Source for ByteBeatSource {
    fn current_frame_len(&self) -> Option<usize> {
        None
    }
    fn channels(&self) -> u16 {
        1
    }
    fn sample_rate(&self) -> u32 {
        SAMPLE_RATE
    }
    fn total_duration(&self) -> Option<Duration> {
        None
    }
}

/// Start playing from t = 0. Does nothing if already playing.
#[frb(sync)]
pub fn start_audio() {
    let mut guard = AUDIO_THREAD.lock().unwrap();
    if let Some(handle) = guard.as_ref() {
        if !handle.is_finished() {
            return;
        }
    }
    guard.take(); // clear a thread that already exited

    POSITION.store(0, Ordering::Relaxed);
    RUNNING.store(true, Ordering::Relaxed);

    *guard = Some(thread::spawn(|| {
        // The output stream must stay alive while sound plays, and it is not
        // Send, so it lives and dies inside this dedicated thread.
        let Ok((_stream, handle)) = OutputStream::try_default() else {
            RUNNING.store(false, Ordering::Relaxed); // no output device
            return;
        };
        let Ok(sink) = Sink::try_new(&handle) else {
            RUNNING.store(false, Ordering::Relaxed);
            return;
        };
        sink.set_volume(0.3); // bytebeat is loud, so keep this low
        sink.append(ByteBeatSource);
        sink.sleep_until_end();
    }));
}

/// Stop playing and wait for the audio thread to finish.
#[frb(sync)]
pub fn stop_audio() {
    RUNNING.store(false, Ordering::Relaxed);
    let handle = AUDIO_THREAD.lock().unwrap().take();
    if let Some(h) = handle {
        let _ = h.join();
    }
}

/// Push the current formula and slider values to the audio thread.
#[frb(sync)]
pub fn set_audio_params(formula: u32, a: u32, b: u32) {
    FORMULA.store(formula, Ordering::Relaxed);
    PARAM_A.store(a, Ordering::Relaxed);
    PARAM_B.store(b, Ordering::Relaxed);
}

/// The audio clock (current t). The UI follows this so the picture matches
/// the sound.
#[frb(sync)]
pub fn audio_position() -> u32 {
    POSITION.load(Ordering::Relaxed)
}

#[frb(sync)]
pub fn is_audio_running() -> bool {
    RUNNING.load(Ordering::Relaxed)
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
