# Bytebeat Viewer (Rust + Flutter example)

Type your own bytebeat or floatbeat code and hear and see it live. Rust compiles
and runs the code; Flutter draws the waveform and the controls.

The Rust side is tested (the parser against known bytebeats, error messages, live
code swapping). The Flutter side hasn't been compiled by me, so expect to fix
small things on first build.

## Setup

```bash
cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen create bytebeat_app
cd bytebeat_app
```

Then overwrite/add these files:

| File | Action |
|------|--------|
| `rust/src/api/bytebeat.rs` | add / replace |
| `rust/src/api/mod.rs` | replace (just `pub mod bytebeat;`) |
| `rust/src/api/simple.rs` | delete |
| `lib/main.dart` | replace |

Add the audio library once:

```bash
cd rust
cargo add rodio@0.20 --no-default-features
cd ..
```

Regenerate bindings and run:

```bash
flutter_rust_bridge_codegen generate
flutter run -d windows
```

## Using it

- Type in the **Code** box. It compiles on every keystroke; if there's a
  mistake you get a message and the last good code keeps playing.
- **Load preset…** fills the box with an example to start from.
- Speaker icon: sound on/off. Circular arrow: back to t = 0.
- **Hz menu**: sample rate (also available in your code as `sr`).
- **Float switch**: off = bytebeat (result wrapped to 0..255),
  on = floatbeat (result is -1..1, anything outside is clipped).
- Sliders `a` and `b` (0 to 24) are available in your code as `a` and `b`.

## Code syntax

JavaScript rules, so most Dollchan-style one-liners work.

| What | Supported |
|------|-----------|
| Variables | `t` (time), `a`, `b` (sliders), `sr` (sample rate) |
| Constants | `PI`, `E` |
| Operators | `+ - * / % **` `& \| ^ ~ << >> >>>` `< <= > >= == != === !==` `&& \|\| !` `? :` |
| Functions | `sin cos tan asin acos atan atan2 abs floor ceil round trunc int sign sqrt log log2 exp pow min max random` (a leading `Math.` is fine) |
| Numbers | `12`, `0.5`, `.5`, `1e3`, `0xFF` |

Bitwise operators convert to 32-bit integers exactly like JavaScript.

**Not supported:** assignments (`x=...`), the comma operator, `;`, arrays,
functions and loops. Code that needs those has to be rewritten as one
expression.

## Where to tinker

- **Presets**: edit `presets()` in `rust/src/api/bytebeat.rs`. Restart the app
  to see changes (no need to run `generate` unless you change a function's
  inputs or outputs).
- **New functions or operators**: the parser and evaluator are at the bottom of
  `bytebeat.rs` (after the `ENGINE-START` comment). To add a function, add a
  variant to `Func`, a line in `lookup_func`, and a case in `Expr::eval`.
- **Sound volume**: `sink.set_volume(0.3)` in `spawn_audio`.
- **Picture size and speed**: `windowSize` and `scrollStep` in `main.dart`.

## Ideas for next steps

- Support `x=...` assignments and the comma operator
- Draw a spectrum next to the waveform
- Save and load your own code snippets to a file
