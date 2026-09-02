import 'dart:io';
import 'dart:math' as math;
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

/// Version of the audio trim/fade/WAV-encoding policy.
///
/// Bump on any behavioral change to [trimAndFadeClip] or the WAV encoding, so a
/// clip produced under the old policy is keyed separately in the synthesis
/// profile and never reused across a change.
const int kTtsAudioPolicyVersion = 1;

/// Cleans up a freshly generated narration clip so back-to-back units join
/// without an audible click or breath "cough" at the seam.
///
/// PocketTTS emits each unit as an isolated clip that can start or end on a
/// non-zero sample (a hard step), and often carries a little dead air or a
/// breath transient at the edges. Playing those clips one after another makes
/// the discontinuity audible between sentences. We (1) trim leading/trailing
/// near-silence (keeping a short pad so onsets aren't clipped) and (2) apply
/// short raised-cosine fades at both edges so every clip starts and ends at
/// zero amplitude.
Float32List trimAndFadeClip(Float32List samples, int sampleRate) {
  if (samples.isEmpty || sampleRate <= 0) return samples;

  var peak = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  if (peak <= 1e-4) return samples; // effectively silent; leave it be

  final gate = peak * 0.02; // -34 dB relative to the clip peak
  var start = 0;
  while (start < samples.length && samples[start].abs() < gate) {
    start++;
  }
  var end = samples.length - 1;
  while (end > start && samples[end].abs() < gate) {
    end--;
  }
  if (end <= start) return samples;

  // Keep ~5 ms of pad on each side so we never clip a speech onset/offset.
  final pad = (sampleRate * 0.005).round();
  start = math.max(0, start - pad);
  end = math.min(samples.length - 1, end + pad);

  final trimmed = Float32List.fromList(
    Float32List.sublistView(samples, start, end + 1),
  );

  // ~8 ms raised-cosine fades remove the boundary click between clips.
  final fade = math.min((sampleRate * 0.008).round(), trimmed.length ~/ 2);
  for (var i = 0; i < fade; i++) {
    final g = 0.5 * (1 - math.cos(math.pi * i / fade));
    trimmed[i] *= g;
    trimmed[trimmed.length - 1 - i] *= g;
  }
  return trimmed;
}

/// Encodes mono float samples as a 16-bit PCM WAV byte buffer.
///
/// Engine-agnostic writer used by backends that don't bundle their own WAV
/// encoder (e.g. the Raven FFI engine). Samples are clamped to [-1, 1] and
/// rounded to signed 16-bit little-endian, matching the sherpa writer's format
/// so downstream playback and cache validation are identical across engines.
Uint8List encodeWavPcm16(Float32List samples, int sampleRate) {
  const int channels = 1;
  const int bitsPerSample = 16;
  const int blockAlign = channels * bitsPerSample ~/ 8;
  final int byteRate = sampleRate * blockAlign;
  final int dataSize = samples.length * blockAlign;
  final int riffSize = 36 + dataSize;

  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);

  void writeTag(int offset, String tag) {
    for (var i = 0; i < 4; i++) {
      bytes[offset + i] = tag.codeUnitAt(i);
    }
  }

  writeTag(0, 'RIFF');
  data.setUint32(4, riffSize, Endian.little);
  writeTag(8, 'WAVE');
  writeTag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // fmt chunk size
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeTag(36, 'data');
  data.setUint32(40, dataSize, Endian.little);

  var offset = 44;
  for (final s in samples) {
    var v = s;
    if (v > 1.0) {
      v = 1.0;
    } else if (v < -1.0) {
      v = -1.0;
    }
    final int i16 = (v * 32767.0).round();
    data.setInt16(offset, i16, Endian.little);
    offset += 2;
  }
  return bytes;
}

/// Atomically writes mono float samples to [path] as a 16-bit PCM WAV.
///
/// Writes to a sibling `.part` file and renames on success so a crashed or
/// cancelled synthesis never leaves a truncated, cacheable final file.
void writeWavPcm16Atomic(String path, Float32List samples, int sampleRate) {
  final bytes = encodeWavPcm16(samples, sampleRate);
  final tmp = File('$path.part');
  tmp.writeAsBytesSync(bytes, flush: true);
  tmp.renameSync(path);
}
