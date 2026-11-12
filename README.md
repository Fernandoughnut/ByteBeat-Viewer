# Bytebeat Viewer (Rust + Flutter example)

Rust generates bytebeat samples; Flutter draws them as a scrolling waveform
with a formula dropdown and two sliders (`a`, `b`).

I couldn't compile or run this where I wrote it, so treat it as untested.
Expect to fix small things on first build.

## Setup

The Rust/Flutter glue (cargokit, `rust_builder`, codegen config) is easiest to
get from the official template, so start from that and drop in my files.

```bash
# one-time tools
cargo install flutter_rust_bridge_codegen
flutter doctor            # make sure Flutter is set up

# generate the project skeleton (name must match the imports in main.dart)
flutter_rust_bridge_codegen create bytebeat_app
cd bytebeat_app
```

Then overwrite/add these files from this folder:

| File | Action |
|------|--------|
| `rust/src/api/bytebeat.rs` | add |
| `rust/src/api/mod.rs` | replace (just `pub mod bytebeat;`) |
| `rust/src/api/simple.rs` | delete |
| `lib/main.dart` | replace |

Regenerate bindings and run:

```bash
flutter_rust_bridge_codegen generate
flutter run -d linux      # or macos / windows / an Android device
```

For live regeneration while you edit Rust:

```bash
flutter_rust_bridge_codegen generate --watch
```

## Sound

Audio plays through the `rodio` crate. Add it once, from the project folder:

```bash
cd rust
cargo add rodio@0.20 --no-default-features
cd ..
```

Then run `flutter_rust_bridge_codegen generate` and `flutter run` as usual.
Click the speaker icon in the top bar to start and stop sound. While sound is
on, the waveform follows the audio clock, and the formula and sliders change
the sound live.

## Where to tinker

- **Add a formula**: add a name to `formula_names()` and a match arm in
  `sample()` in `rust/src/api/bytebeat.rs`. Re-run `generate`.
- **Change the window**: `windowSize` and `scrollStep` in `main.dart`.
- **Change what the sliders do**: `a` and `b` are passed straight into the
  formulas as shift amounts or multipliers.

## Ideas for next steps

- Change `SAMPLE_RATE` in `bytebeat.rs` (8000, 11025, 22050, 44100) and hear the pitch shift
- Make `render_bytebeat` async or stream samples with `StreamSink`
- Parse a typed expression in Rust instead of hardcoded formulas
