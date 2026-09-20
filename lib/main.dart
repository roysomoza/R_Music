import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/main_navigation_screen.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.pure_audio.channel.audio',
      androidNotificationChannelName: 'R Music',
      androidNotificationChannelDescription: 'Reproductor de música R Music',
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: const Color(0xFF007AFF),
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground initialization with custom drawable error: $e');
    try {
      // Safe fallback to system mipmap launcher icon if custom drawable fails
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.pure_audio.channel.audio',
        androidNotificationChannelName: 'R Music',
        androidNotificationChannelDescription: 'Reproductor de música R Music',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
    } catch (fallbackError) {
      debugPrint('JustAudioBackground fallback initialization error: $fallbackError');
    }
  }
  runApp(const PureAudioApp());
}

class PureAudioApp extends StatelessWidget {
  const PureAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
