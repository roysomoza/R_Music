import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel interface communicating with Android native Equalizer & BassBoost APIs.
class EqualizerChannel {
  static const MethodChannel _channel =
      MethodChannel('com.example.pure_audio/equalizer');

  static const List<String> fallbackPresets = [
    'Flat',
    'Bass Boost',
    'Rock',
    'Pop',
    'Electronic',
    'Hip Hop',
    'Acoustic',
    'Classical',
  ];

  static bool _isAvailable = false;

  /// Initializes the native Equalizer attached to the given [audioSessionId].
  static Future<bool> initEqualizer(int audioSessionId) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('init', {
        'audioSessionId': audioSessionId,
      });
      _isAvailable = result ?? false;
      return _isAvailable;
    } on PlatformException catch (e) {
      debugPrint('Equalizer platform error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Equalizer error: $e');
      return false;
    }
  }

  /// Enables or disables the native Equalizer.
  static Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isAndroid || !_isAvailable) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves available equalizer presets from the system.
  static Future<List<String>> getPresets() async {
    if (!Platform.isAndroid || !_isAvailable) return fallbackPresets;

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getPresets');
      if (result != null && result.isNotEmpty) {
        return result.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return fallbackPresets;
  }

  /// Applies an equalizer preset by index or name.
  static Future<bool> setPreset(int presetIndex) async {
    if (!Platform.isAndroid || !_isAvailable) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setPreset', {'preset': presetIndex});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets the Bass Boost strength (range 0 to 1000).
  static Future<bool> setBassBoost(int strength) async {
    if (!Platform.isAndroid || !_isAvailable) return false;

    try {
      final clamped = strength.clamp(0, 1000);
      final result = await _channel.invokeMethod<bool>('setBassBoost', {'strength': clamped});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets an individual equalizer band level in milliBels.
  static Future<bool> setBandLevel(int band, int level) async {
    if (!Platform.isAndroid || !_isAvailable) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setBandLevel', {
        'band': band,
        'level': level,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
