# 🎵 R Music (v2.0.0)

**R Music** es un reproductor de música local de alto rendimiento diseñado para **Android** e **iOS**, construido con Flutter bajo los principios de **Clean Architecture (Layer-First)** y el patrón reactivo unidireccional **MVI (Model-View-Intent)**.

---

## ✨ Características Principales

- **🎨 Identidad Visual "Pure Black & Neon Blue":**
  - Fondo negro puro (`#000000`) optimizado para pantallas AMOLED.
  - Tarjetas y superficies elevadas en azul profundo (`#161F2E`).
  - Acentos brillantes en azul neón (`#00E5FF`) y azul primario (`#007AFF`).
  - Tipografía moderna con Google Fonts Inter.

- **⚡ Motor Inteligente de Deduplicación $O(n)$:**
  - Resuelve las copias duplicadas de descargadores como Snaptube, YouTube o Telegram (ej. `(MP3_160K)`, `(MP3_128K)`, `(1)`, `(2)`, `_160k`).
  - Fusión automática en una sola pista conservando la de mayor tamaño (`fileSize` / bitrate superior).
  - Preservación inteligente de metadatos de artista y duración leída.

- **🎛️ Ecualizador y Bass Boost por Hardware:**
  - Comunicación nativa por `MethodChannel` en Kotlin con la API de audio de Android (`android.media.audiofx.Equalizer` y `BassBoost`).
  - Presets de audio y control de bandas en tiempo real sin latencia.

- **⏱️ Temporizador de Apagado (Sleep Timer):**
  - Modos rápidos de 15m, 30m, 45m, 60m o "Al finalizar la canción".
  - Pausa automática suave y notificación en pantalla.

- **📝 Letras Sincronizadas (Synced Lyrics):**
  - Soporte para archivos `.lrc` con resaltado automático en tiempo real sincronizado con la reproducción.

- **🔒 Controles en Pantalla de Bloqueo y Notificaciones:**
  - Soporte nativo para `audio_service` y `just_audio_background` con carátula oficial y controles de pista.

---

## 🏛️ Arquitectura del Proyecto (Layer-First)

```text
lib/
├── core/                  # Utilidades comunes, tema y canales de plataforma
│   ├── platform/          # EqualizerChannel y PermissionHandlerService
│   ├── theme/             # AppTheme (colores, sombras, degradados)
│   └── utils/             # TrackNormalizer y LrcParser
├── domain/                # Entidades inmutables y contratos abstractos
│   ├── entities/          # Track, Album, Artist, Folder, LyricLine
│   └── repositories/      # IMusicRepository, IAudioPlayerRepository
├── data/                  # Implementación de datos y acceso al hardware
│   ├── datasources/       # LocalDatabase, Id3Reader, ScannerWorker (Isolate)
│   ├── models/            # TrackDto, FolderDto
│   └── repositories/      # MusicRepositoryImpl, AudioPlayerRepositoryImpl
├── presentation/          # Gestión de estado y componentes visuales
│   ├── mvi/               # PlayerStore, PlayerState, PlayerIntent, PlayerEffect
│   ├── screens/           # ExpandedPlayerScreen, LyricsView, etc.
│   └── widgets/           # SleepTimerDialog, EqualizerBottomSheet
└── screens/               # Pantallas principales (Home, Biblioteca, Favoritos)
```

---

## 🚀 Compilación y Despliegue

### Requisitos
- Flutter SDK `>= 3.11.5`
- Android SDK con Platform Tools (API 33+)
- Java JDK 17 o 21

### Comandos de Ejecución
```bash
# Obtener dependencias
flutter pub get

# Ejecutar en dispositivo conectado
flutter run

# Ejecutar pruebas unitarias
flutter test

# Compilar APK Universal (Compatible con todos los Android)
flutter build apk --release

# Compilar APKs Ligeros por Arquitectura (arm64, armeabi, x86)
flutter build apk --release --split-per-abi
```

---

## 📄 Licencia y Autoría
Desarrollado para **R Music**. Todos los derechos reservados.

