# 🎵 R Music (v2.0.0)

**R Music** es un reproductor de música local de alto rendimiento y fidelidad sonora diseñado para **Android**, **iOS** y **Windows**, construido con Flutter bajo los principios de **Clean Architecture (Layer-First)** y el patrón reactivo unidireccional **MVI (Model-View-Intent)**.

Ofrece una experiencia sin interrupciones, pensada para audiófilos y usuarios con bibliotecas de audio extensas, garantizando velocidad extrema, tolerancia a fallos y una interfaz moderna con estética cyberpunk minimalista.

---

## ✨ Resumen de Características del Programa

### 🎨 1. Experiencia Visual "Pure Black & Neon Blue"

- **Diseño AMOLED-Friendly:** Fondo negro puro (`#000000`) para minimizar el consumo de batería en pantallas OLED/AMOLED.
- **Jerarquía Visual Neón:** Superficies elevadas y tarjetas en azul profundo (`#161F2E`), resaltadas con acentos en azul neón (`#00E5FF`) y azul primario (`#007AFF`).
- **Pista Activa con Resplandor y Ecualizador:** La canción en reproducción destaca con un sutil halo neón azul y barras animadas de espectro de audio en tiempo real.
- **Tipografía Moderna:** Integración fluida con Google Fonts *Inter*.

---

### 🎧 2. Reproducción de Audio y Control Total

- **Reproductor Expandido (`ExpandedPlayerScreen`):**
  - Carátula de vinilo/álbum giratoria con animación de reproducción fluida.
  - Barra de progreso con indicador de buffer y tiempo transcurrido / restante.
  - Controles de reproducción: Play/Pausa, anterior/siguiente, shuffle determinista y ciclo de repetición (Off, All, One).
  - Control de velocidad de reproducción (0.5x a 2.0x).
- **Mini Reproductor Anclado (`PlayerDock`):**
  - Acceso persistente en la parte inferior de todas las pantallas principales.
  - Mini ecualizador reactivo, controles de play/pause, siguiente, anterior y botón rápido de favoritos.
  - Toque para expandir sin perder la posición de scroll ni el estado actual.
- **Restauración de Estado al Inicio:** Carga automática de la última cola y posición de reproducción guardada (`playback_state.json`), permitiendo reanudar inmediatamente.
- **Manejo Inteligente de Audio Focus:** Integración con `audio_session` para gestionar llamadas entrantes, notificaciones (`ducking`), y pausa automática al desconectar auriculares (`becoming noisy`).
- **Controles en Segundo Plano y Pantalla de Bloqueo:** Notificaciones interactivas de sistema mediante `just_audio_background` y `audio_service`.

---

### 🎛️ 3. Herramientas de Audio Avanzadas

- **Ecualizador y Bass Boost por Hardware:**
  - Comunicación nativa por `MethodChannel` en Android (`android.media.audiofx.Equalizer` y `BassBoost`).
  - Presets de sonido (Rock, Pop, Jazz, Bass, Flat) y ajuste manual de bandas de frecuencia en tiempo real.
- **Letras Sincronizadas (`.lrc`):**
  - Detección y parseo automático de archivos `.lrc` emparejados localmente.
  - Desplazamiento y resaltado sincronizado verso a verso con la posición de la pista.
- **Temporizador de Apagado (Sleep Timer):**
  - Modos rápidos de 15, 30, 45, 60 minutos o "Al finalizar la canción".
  - Pausa suave progresiva para evitar cortes abruptos al conciliar el sueño.

---

### 🔍 4. Motor de Búsqueda y Deduplicación Inteligente

- **Buscador Multicriterio Flexible:**
  - Búsqueda en tiempo real que cruza simultáneamente título y nombre del artista.
  - Normalización fonética que ignora mayúsculas y acentos diacríticos (ejemplo: buscar `"Ruben Blades"` encuentra `"Rubén Blades"`).
  - Admite palabras en orden arbitrario y fallback automático al nombre del archivo físico cuando no hay metadatos ID3.
- **Deduplicación Automática $O(n)$:**
  - Detecta y consolida pistas duplicadas generadas por descargadores (Snaptube, YouTube, Vidmate, Telegram, sufijos como `(1)`, `(MP3_160K)`, `(Official Audio)`, `_copia`).
  - Conserva automáticamente el archivo con mayor tasa de bits o tamaño (`fileSize`), descartando copias redundantes sin intervención manual.

---

### 📂 5. Organización y Gestión de Biblioteca

- **Carpetas Físicas y Virtuales:** Agrupación automática por carpetas del almacenamiento y creación de carpetas personalizadas.
- **Vistas Adaptables en Biblioteca:**
  - Vista cronológica agrupada por fecha de agregado con etiquetas distintivas (*Hoy*, *Ayer*, *Esta semana*, *Este mes*).
  - Vista plana con conteo total y ordenamiento por fecha, título, artista o tamaño.
- **Sistema Unificado de Favoritos (SSOT):**
  - Persistencia centralizada en `LocalDatabase` (`favorites_db.json`) sincronizada en tiempo real mediante `favoritesStream`.
  - Actualización optimista instantánea: el botón de corazón cambia de inmediato al interactuar en cualquier pantalla (`Home`, `Biblioteca`, `Favoritos`, `Detalle de Carpeta`, `PlayerDock` o `ExpandedPlayer`).
  - Migración transparente y automática desde versiones anteriores basadas en rutas.
- **Menú de Opciones Contextual (`TrackOptionsSheet`):**
  - Reproducir a continuación, agregar/quitar de carpetas, alternar favorito, ver detalles del archivo o eliminar pista (solo de la app o borrado físico del almacenamiento).

---

### 🛡️ 6. Resiliencia, Estabilidad y Rendimiento

- **Tolerancia a Archivos Corruptos o Inexistentes:** Sistema de guardas que detecta fallos de lectura física y evita bucles infinitos de saltos (*infinite skip loops*), alertando al usuario mediante `SnackBar`.
- **Preservación Determinista del Índice:** Al eliminar una pista anterior a la que está sonando, el reproductor recalcula el índice exacto para evitar desfases (*off-by-one desync*) o saltos visuales a canciones adyacentes.
- **Identidad Estable de Widgets (`ValueKey`):** Cada elemento del listado (`TrackTile`) cuenta con clave única basada en ID, evitando fallos de renderizado en reciclaje de listas `ListView`.
- **Escritura Atómica en Disco (`Atomic File Write`):** Todas las operaciones de guardado de base de datos (`tracks_db.json`, `favorites_db.json`, `folders.json`) escriben primero en archivos temporales `.tmp` con `flush: true` antes de renombrar, impidiendo la corrupción de datos ante cierres inesperados.
- **Serialización en Background (`compute`):** Procesamiento de JSON en hilos secundarios para colecciones grandes (+300 pistas), eliminando micro-congelamientos (*UI jank*).

---

## 🏛️ Arquitectura del Proyecto (Layer-First)

```text
lib/
├── core/                  # Utilidades comunes, tema y canales de plataforma
│   ├── platform/          # EqualizerChannel y PermissionHandlerService
│   ├── theme/             # AppTheme (paleta Pure Black, Neon Blue, estilos)
│   └── utils/             # TrackNormalizer, LrcParser y utilidades de ordenación
├── domain/                # Entidades inmutables y contratos abstractos
│   ├── entities/          # Track, Album, Artist, Folder, LyricLine
│   └── repositories/      # IMusicRepository, IAudioPlayerRepository
├── data/                  # Implementación de datos y acceso al hardware
│   ├── datasources/       # LocalDatabase (JSON atómico), Id3Reader, ScannerWorker
│   ├── models/            # TrackDto, FolderDto, PlayerPlaybackState
│   └── repositories/      # MusicRepositoryImpl, AudioPlayerRepositoryImpl
├── presentation/          # Gestión de estado reactivo y componentes UI
│   ├── mvi/               # PlayerStore, PlayerState, PlayerIntent, PlayerEffect
│   └── screens/           # ExpandedPlayerScreen, LyricsView, etc.
├── screens/               # Pantallas principales (Home, Library, Favorites, FolderDetail)
├── services/              # MusicRepository de alto nivel, MetadataResolutionService
└── widgets/               # TrackTile, PlayerDock, TrackOptionsSheet, Modales
```

---

## 🚀 Compilación y Despliegue

### Requisitos Previos

- **Flutter SDK:** `>= 3.11.5`
- **Dart SDK:** `>= 3.7.0`
- **Android SDK:** Platform Tools con API 33+
- **JDK:** Java JDK 17 o 21

## 🧪 Pruebas Automatizadas

El proyecto cuenta con una cobertura integral de pruebas que validan:

- **Flujos MVI:** Transición de estados de reproducción, colas y restauración.
- **Normalización y Búsqueda:** Búsqueda combinada título/artista y deduplicación $O(n)$ con benchmarks de rendimiento.
- **Persistencia y Migración:** Integridad de escritura atómica y migración de favoritos.
- **Ciclo de Vida de UI:** Reactividad de favoritos en widgets y modales.

---

## 📄 Licencia y Autoría

Desarrollado para **R Music**. Todos los derechos reservados.
