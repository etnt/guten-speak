import 'dart:io';
import 'dart:typed_data';

/// Decoded mono PCM audio as normalized floats in [-1, 1].
class Wave {
  const Wave({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;
}

/// Minimal, tolerant WAV reader.
///
/// Unlike sherpa-onnx's `readWave`, this handles a `fmt ` chunk larger than 16
/// bytes (e.g. WAVE_FORMAT_EXTENSIBLE, which the macOS recorder emits) and
/// IEEE float samples, and it downmixes multi-channel audio to mono.
///
/// When [normalize] is true, the audio is peak-normalized (see
/// [conditionReference]) so a quietly recorded reference still yields a strong
/// voice embedding.
Wave readWavAsFloat32(String path, {bool normalize = false}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw Exception('Reference audio not found: $path');
  }
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  if (bytes.length < 12 ||
      _tag(bytes, 0) != 'RIFF' ||
      _tag(bytes, 8) != 'WAVE') {
    throw Exception('Not a RIFF/WAVE file: $path');
  }

  var format = 1; // 1 = PCM, 3 = IEEE float, 0xFFFE = extensible
  var channels = 1;
  var sampleRate = 0;
  var bitsPerSample = 16;
  var dataOffset = -1;
  var dataSize = 0;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 40) {
        // Extensible: real format is the first 2 bytes of the SubFormat GUID.
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      dataOffset = body;
      dataSize = size;
      break;
    }
    // Chunks are word-aligned (padded to even size).
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (dataOffset < 0 || sampleRate == 0) {
    throw Exception('Missing fmt/data chunk in WAV: $path');
  }
  if (dataOffset + dataSize > bytes.length) {
    dataSize = bytes.length - dataOffset;
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  if (bytesPerSample == 0 || channels == 0) {
    throw Exception('Invalid WAV format: $path');
  }
  final frameCount = dataSize ~/ (bytesPerSample * channels);
  final out = Float32List(frameCount);

  double readSample(int byteIndex) {
    switch (format) {
      case 3: // IEEE float
        if (bitsPerSample == 64) {
          return data.getFloat64(byteIndex, Endian.little);
        }
        return data.getFloat32(byteIndex, Endian.little);
      default: // PCM integer
        switch (bitsPerSample) {
          case 8:
            return (bytes[byteIndex] - 128) / 128.0;
          case 16:
            return data.getInt16(byteIndex, Endian.little) / 32768.0;
          case 24:
            final b0 = bytes[byteIndex];
            final b1 = bytes[byteIndex + 1];
            final b2 = bytes[byteIndex + 2];
            var v = b0 | (b1 << 8) | (b2 << 16);
            if (v & 0x800000 != 0) v |= ~0xFFFFFF; // sign-extend
            return v / 8388608.0;
          case 32:
            return data.getInt32(byteIndex, Endian.little) / 2147483648.0;
          default:
            throw Exception('Unsupported bit depth: $bitsPerSample');
        }
    }
  }

  for (var i = 0; i < frameCount; i++) {
    final frameStart = dataOffset + i * bytesPerSample * channels;
    if (channels == 1) {
      out[i] = readSample(frameStart);
    } else {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += readSample(frameStart + c * bytesPerSample);
      }
      out[i] = sum / channels;
    }
  }

  if (normalize && out.isNotEmpty) {
    return Wave(samples: conditionReference(out), sampleRate: sampleRate);
  }

  return Wave(samples: out, sampleRate: sampleRate);
}

/// Prepares a recorded reference clip so it yields a usable speaker embedding.
///
/// Phone recordings are often quiet with lots of dead air (e.g. RMS ≈ −35 dBFS,
/// >50% near-silence). Feeding that straight in makes the embedding collapse to
/// noise and PocketTTS runs away generating white noise. We (1) trim leading and
/// trailing near-silence so the embedding is computed over speech, and
/// (2) normalize using a high percentile (not the absolute peak) so a single
/// transient doesn't cap the gain, then hard-clip the rare overshoots.
Float32List conditionReference(Float32List samples) {
  var peak = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  if (peak <= 1e-4) return samples; // effectively silent; nothing to do

  // Trim leading/trailing samples below -34 dB relative to the peak.
  final gate = peak * 0.02;
  var start = 0;
  while (start < samples.length && samples[start].abs() < gate) {
    start++;
  }
  var end = samples.length - 1;
  while (end > start && samples[end].abs() < gate) {
    end--;
  }
  final trimmed = (start > 0 || end < samples.length - 1)
      ? Float32List.sublistView(samples, start, end + 1)
      : samples;
  if (trimmed.isEmpty) return samples;

  // Robust level: 99th-percentile magnitude ignores rare spikes so quiet
  // speech is actually lifted instead of being limited by one transient.
  final mags = Float32List(trimmed.length);
  for (var i = 0; i < trimmed.length; i++) {
    mags[i] = trimmed[i].abs();
  }
  mags.sort();
  final p99 = mags[((mags.length - 1) * 0.99).floor()];
  if (p99 <= 1e-4) return trimmed;

  var gain = 0.9 / p99;
  if (gain < 1.0) gain = 1.0; // never make an already-strong recording quieter
  if (gain > 12.0) gain = 12.0; // avoid amplifying pure noise without bound
  for (var i = 0; i < trimmed.length; i++) {
    var v = trimmed[i] * gain;
    if (v > 1.0) {
      v = 1.0;
    } else if (v < -1.0) {
      v = -1.0;
    }
    trimmed[i] = v;
  }
  return trimmed;
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
