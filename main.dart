import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:bytebeat_app/src/rust/api/bytebeat.dart';
import 'package:bytebeat_app/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const BytebeatApp());
}

class BytebeatApp extends StatelessWidget {
  const BytebeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bytebeat Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ViewerPage(),
    );
  }
}

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  static const int windowSize = 1024; // samples drawn per frame
  static const int scrollStep = 128; // samples to advance per tick

  late final List<String> _names = formulaNames();
  int _formula = 0;
  double _a = 8;
  double _b = 12;
  int _start = 0;
  bool _playing = true;
  bool _audioOn = false;
  Timer? _timer;
  Uint8List _samples = Uint8List(0);

  @override
  void initState() {
    super.initState();
    _render();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_audioOn) {
        // Follow the audio clock so the picture matches what you hear.
        final pos = audioPosition();
        _start = pos > windowSize ? pos - windowSize : 0;
        if (!isAudioRunning()) _audioOn = false; // e.g. no output device
      } else if (_playing) {
        _start += scrollStep;
      } else {
        return;
      }
      _render();
    });
  }

  @override
  void dispose() {
    stopAudio();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleAudio() {
    if (_audioOn) {
      stopAudio();
      setState(() => _audioOn = false);
    } else {
      setAudioParams(formula: _formula, a: _a.round(), b: _b.round());
      startAudio();
      setState(() => _audioOn = true);
    }
  }

  void _render() {
    // Keep the audio thread in sync with the UI controls.
    setAudioParams(formula: _formula, a: _a.round(), b: _b.round());
    // One synchronous call into Rust per frame.
    final data = renderBytebeat(
      formula: _formula,
      start: _start,
      len: windowSize,
      a: _a.round(),
      b: _b.round(),
    );
    setState(() => _samples = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bytebeat Viewer'),
        actions: [
          IconButton(
            tooltip: _audioOn ? 'Stop sound' : 'Play sound',
            icon: Icon(_audioOn ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleAudio,
          ),
          IconButton(
            tooltip: _playing ? 'Pause' : 'Play',
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            onPressed: () => setState(() => _playing = !_playing),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: WavePainter(
                      _samples,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: _formula,
              isExpanded: true,
              items: [
                for (var i = 0; i < _names.length; i++)
                  DropdownMenuItem(value: i, child: Text(_names[i])),
              ],
              onChanged: (v) {
                if (v == null) return;
                _formula = v;
                _render();
              },
            ),
            _ParamSlider(
              label: 'a',
              value: _a,
              onChanged: (v) {
                _a = v;
                _render();
              },
            ),
            _ParamSlider(
              label: 'b',
              value: _b,
              onChanged: (v) {
                _b = v;
                _render();
              },
            ),
            Text('t = $_start', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 24, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 24,
            divisions: 24,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 28, child: Text(value.round().toString())),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  WavePainter(this.samples, this.color);

  final Uint8List samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i / (samples.length - 1) * size.width;
      final y = size.height - (samples[i] / 255.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter old) => old.samples != samples;
}
