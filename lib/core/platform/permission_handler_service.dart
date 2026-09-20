import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service dedicated to handling Scoped Storage and audio permissions safely.
class PermissionHandlerService {
  /// Requests necessary audio and storage permissions on Android devices.
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // 1. Android 13+ (API 33+) requires Permission.audio
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) {
        return true;
      }

      final audioRequestResult = await Permission.audio.request();
      if (audioRequestResult.isGranted) {
        return true;
      }

      // 2. Fallback for Android <= 12 (API <= 32)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }

      final storageRequestResult = await Permission.storage.request();
      if (storageRequestResult.isGranted) {
        return true;
      }

      // 3. Fallback check for manageExternalStorage (Android 11+ broad storage access)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) {
        return true;
      }
    } catch (e) {
      debugPrint('Exception while requesting storage permissions: $e');
    }

    return false;
  }

  /// Checks whether storage access is currently granted.
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final audioGranted = await Permission.audio.isGranted;
    if (audioGranted) return true;

    final storageGranted = await Permission.storage.isGranted;
    if (storageGranted) return true;

    final manageGranted = await Permission.manageExternalStorage.isGranted;
    return manageGranted;
  }

  /// Requests notification permissions for Android 13 - 16 (API 33+ / HyperOS).
  /// Required for the foreground service notification controls in the status bar.
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        return true;
      }

      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('Exception while requesting notification permission: $e');
      return false;
    }
  }

  /// Checks whether notification permission is granted.
  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }
}

