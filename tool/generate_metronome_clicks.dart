// One-shot generator for the metronome click WAV assets (T052).
//
// Produces two minimal 16-bit mono PCM WAV files at 8 kHz:
//   - assets/audio/metronome_click_high.wav : 1500 Hz × 20 ms (accent / downbeat)
//   - assets/audio/metronome_click_low.wav  : 1000 Hz × 20 ms (offbeat)
//
// Why 8 kHz? The highest tone is 1500 Hz (Nyquist 750 Hz — too low!).
// We use 8 kHz sample rate, so 1000 Hz and 1500 Hz tones are well
// below the 4 kHz Nyquist. Bit depth 16 keeps the file tiny while
// keeping the click sharp on phone speakers (20 ms is well above the
// perceptual threshold).
//
// Run with:
//   dart run tool/generate_metronome_clicks.dart
//
// This script is intentionally NOT registered in pubspec as an
// executable and is not part of the production app. It exists to
// regenerate the two checked-in WAVs if they are ever lost.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 8000;
const int _bitsPerSample = 16;
const int _numChannels = 1;

void main() {
  final Directory outDir = Directory('assets/audio');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  _writeSineClick(
    path: 'assets/audio/metronome_click_high.wav',
    frequencyHz: 1500,
    durationMs: 20,
  );
  _writeSineClick(
    path: 'assets/audio/metronome_click_low.wav',
    frequencyHz: 1000,
    durationMs: 20,
  );

  stdout.writeln('Generated metronome click WAVs under assets/audio/.');
}

void _writeSineClick({
  required String path,
  required int frequencyHz,
  required int durationMs,
}) {
  final int numSamples = (_sampleRate * durationMs) ~/ 1000;
  // Apply a short linear attack / release envelope to avoid the
  // 0→1 step producing an audible "pop" on the first/last sample.
  final int envelopeSamples = math.min(numSamples ~/ 4, 40);

  final ByteData pcm = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final double t = i / _sampleRate;
    double envelope = 1.0;
    if (i < envelopeSamples) {
      envelope = i / envelopeSamples;
    } else if (i > numSamples - envelopeSamples) {
      envelope = (numSamples - i) / envelopeSamples;
    }
    final double sample =
        math.sin(2 * math.pi * frequencyHz * t) * envelope * 0.85;
    final int intSample = (sample * 32767).round().clamp(-32768, 32767);
    pcm.setInt16(i * 2, intSample, Endian.little);
  }

  final File f = File(path);
  f.writeAsBytesSync(_wrapAsWav(pcm.buffer.asUint8List()));
}

Uint8List _wrapAsWav(Uint8List pcm) {
  // 44-byte RIFF/WAVE header for PCM, little-endian everywhere.
  final int byteRate = _sampleRate * _numChannels * _bitsPerSample ~/ 8;
  final int blockAlign = _numChannels * _bitsPerSample ~/ 8;
  final int dataSize = pcm.length;
  final int fileSize = 36 + dataSize;

  final ByteData header = ByteData(44);
  // "RIFF"
  header.setUint8(0, 0x52);
  header.setUint8(1, 0x49);
  header.setUint8(2, 0x46);
  header.setUint8(3, 0x46);
  // file size - 8
  header.setUint32(4, fileSize, Endian.little);
  // "WAVE"
  header.setUint8(8, 0x57);
  header.setUint8(9, 0x41);
  header.setUint8(10, 0x56);
  header.setUint8(11, 0x45);
  // "fmt "
  header.setUint8(12, 0x66);
  header.setUint8(13, 0x6d);
  header.setUint8(14, 0x74);
  header.setUint8(15, 0x20);
  // fmt chunk size = 16 (PCM)
  header.setUint32(16, 16, Endian.little);
  // audio format = 1 (PCM)
  header.setUint16(20, 1, Endian.little);
  // num channels
  header.setUint16(22, _numChannels, Endian.little);
  // sample rate
  header.setUint32(24, _sampleRate, Endian.little);
  // byte rate
  header.setUint32(28, byteRate, Endian.little);
  // block align
  header.setUint16(32, blockAlign, Endian.little);
  // bits per sample
  header.setUint16(34, _bitsPerSample, Endian.little);
  // "data"
  header.setUint8(36, 0x64);
  header.setUint8(37, 0x61);
  header.setUint8(38, 0x74);
  header.setUint8(39, 0x61);
  // data size
  header.setUint32(40, dataSize, Endian.little);

  final Uint8List out = Uint8List(44 + dataSize);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, 44 + dataSize, pcm);
  return out;
}
