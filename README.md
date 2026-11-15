Bytebeat Viewer (Rust + Flutter example)
Rust generates bytebeat samples; Flutter draws them as a scrolling waveform
with a formula dropdown and two sliders (`a`, `b`).
I couldn't compile or run this where I wrote it, so treat it as untested.
Expect to fix small things on first build.
Setup
The Rust/Flutter glue (cargokit, `rust\_builder`, codegen config) is easiest to
get from the official template, so start from that and drop in my files.
```bash
# one-time tools
cargo install flutter\_rust\_bridge\_codegen
flutter doctor            # make sure Flutter is set up

# generate the project skeleton (name must match the imports in main.dart)
flutter\_rust\_bridge\_codegen create bytebeat\_app
cd bytebeat\_app
```
Then overwrite/add these files from this folder:
File	Action
`rust/src/api/bytebeat.rs`	add
`rust/src/api/mod.rs`	replace (just `pub mod bytebeat;`)
`rust/src/api/simple.rs`	delete
`lib/main.dart`	replace
Regenerate bindings and run:
```bash
flutter\_rust\_bridge\_codegen generate
flutter run -d linux      # or macos / windows / an Android device
```
For live regeneration while you edit Rust:
```bash
flutter\_rust\_bridge\_codegen generate --watch
```
Where to tinker
Add a formula: add a name to `formula\_names()` and a match arm in
`sample()` in `rust/src/api/bytebeat.rs`. Re-run `generate`.
Change the window: `windowSize` and `scrollStep` in `main.dart`.
Change what the sliders do: `a` and `b` are passed straight into the
formulas as shift amounts or multipliers.
Ideas for next steps
Play the samples as audio (e.g. the `rodio` or `cpal` crate on the Rust side)
Make `render\_bytebeat` async or stream samples with `StreamSink`
Parse a typed expression in Rust instead of hardcoded formulas
