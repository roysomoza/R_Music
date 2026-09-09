# 📱 R Music - Guía de Instalación y Despliegue en iPhone (iOS)

Esta guía explica detalladamente cómo tomar el archivo instalable `.ipa` generado por el pipeline de integración continua (o localmente) e instalarlo directamente en un iPhone físico.

---

## 📥 Obtener el Instalador `.ipa` desde GitHub Actions

1. Ve a tu repositorio en GitHub: [`https://github.com/roysomoza/R_Music`](https://github.com/roysomoza/R_Music).
2. Entra en la pestaña **Actions**.
3. Selecciona la ejecución más reciente del workflow **Build iOS Installer (.ipa)**.
4. Desplázate hacia abajo hasta la sección **Artifacts**.
5. Descarga el paquete comprimido `R_Music_v2.0.0_iOS_Installer.zip` (o `app-release.ipa`).
6. Descomprime el archivo `.zip` en tu PC Windows para extraer el archivo `.ipa`.

---

## 🚀 Método A: Instalación Directa mediante Sideloadly (Recomendado para Windows)

Este método es 100% gratuito y no requiere pagar la cuenta de desarrollador de Apple ($99/año). Utiliza tu Apple ID personal para auto-firmar la aplicación en tu propio dispositivo.

### Paso 1: Requisitos previos en Windows
Para que las utilidades de conexión con iOS funcionen correctamente, es fundamental instalar las versiones independientes de Apple (y **NO** las versiones de la tienda Microsoft Store):
1. **iTunes para Windows (64-bit)**: [Descarga directa de Apple](https://www.apple.com/itunes/download/win64).
2. **iCloud para Windows**: [Descarga directa de Apple](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8109-AE433825838F/iCloudSetup.exe).
3. **Sideloadly**: [Descargar desde sideloadly.io](https://sideloadly.io/).

> [!IMPORTANT]
> Si tienes instalados iTunes o iCloud desde Microsoft Store, desinstálalos e instala los ejecutables oficiales enlazados arriba. Reinicia tu computadora si es necesario.

### Paso 2: Conexión y preparación del iPhone
1. Conecta el iPhone a tu PC mediante un cable USB original o certificado MFi.
2. Desbloquea la pantalla de tu iPhone. Si aparece el mensaje **"¿Confiar en este ordenador?"**, pulsa **Confiar** e introduce el código de desbloqueo.
3. Abre iTunes una vez para confirmar que el dispositivo es reconocido y pulsa en "Continuar".

### Paso 3: Firma e instalación con Sideloadly
1. Abre **Sideloadly** en tu PC.
2. Verifica que tu iPhone aparezca seleccionado en el campo **Device**.
3. Arrastra el archivo `R_Music_v2.0.0.ipa` a la ventana de Sideloadly (o pulsa en el icono de IPA para seleccionarlo).
4. En el campo **Apple ID**, introduce tu correo de Apple ID.
5. Haz clic en el botón **Start**.
6. Introduce la contraseña de tu Apple ID (y el código de autenticación de 2 factores que llegará a tu iPhone si está activado).
   - *Nota:* Sideloadly únicamente usa estas credenciales para solicitar el certificado de desarrollo temporal directamente a los servidores de Apple.
7. Espera unos momentos hasta que la barra de progreso muestre `Done.` y el icono de **R Music** aparezca en la pantalla de inicio de tu iPhone.

### Paso 4: Autorizar el certificado en iOS
Al intentar abrir la aplicación por primera vez, iOS mostrará un aviso de *Desarrollador empresarial no confiable* o *Desarrollador no confiable*. Sigue estos pasos para habilitarla:
1. En tu iPhone, abre **Ajustes**.
2. Ve a **General** > **VPN y gestión de dispositivos**.
3. Bajo **App de desarrollador**, pulsa sobre tu Apple ID.
4. Pulsa en **Confiar en "[tu correo de Apple ID]"** y confirma la selección.

### Paso 5: Activar Modo de desarrollador (Solo iOS 16, 17 o superior)
En versiones modernas de iOS, Apple requiere habilitar el modo desarrollador para ejecutar apps auto-firmadas:
1. En el iPhone, ve a **Ajustes** > **Privacidad y seguridad**.
2. Desplázate hacia el final hasta encontrar **Modo de desarrollador**.
3. Activa la casilla. El iPhone solicitará reiniciarse.
4. Tras el reinicio, desbloquea el iPhone y pulsa **Activar** en el diálogo que aparece, confirmando con tu código de acceso.

¡Listo! Ya puedes abrir y disfrutar de **R Music** de manera fluida y nativa.

> [!NOTE]
> Con una cuenta gratuita de Apple ID, los certificados de desarrollo tienen una validez de 7 días. Transcurrido ese periodo, basta con conectar nuevamente el teléfono a Sideloadly y pulsar "Start" para renovar la firma por otros 7 días sin perder tu configuración ni canciones.

---

## 🌐 Método B: Despliegue Oficial (Apple Developer Program - $99/año)

Si cuentas con una cuenta oficial paga del Apple Developer Program:

### Opción 1: TestFlight (Pruebas con usuarios sin cables)
1. Genera una clave API de App Store Connect o configura tus certificados de distribución (`.p12` y MobileProvision) en los Secrets de GitHub:
   - `APPLE_CERTIFICATE` (Certificado base64).
   - `APPLE_CERTIFICATE_PASSWORD`.
   - `PROVISIONING_PROFILE`.
2. El pipeline ejecutará `flutter build ipa --export-options-plist=ios/ExportOptions.plist`.
3. Sube el `.ipa` directamente a App Store Connect mediante `xcrun altool` o Fastlane.
4. Invita a los usuarios a través de la app oficial **TestFlight** disponible en la App Store. Las compilaciones duran 90 días activos.

### Opción 2: Ad-Hoc / Enterprise
1. Registra los UDIDs de los dispositivos de destino en el portal de desarrolladores de Apple.
2. Genera un perfil de aprovisionamiento de tipo *Ad-Hoc*.
3. Exporta el `.ipa` firmado con dicho perfil.
4. Distribuye mediante plataformas de distribución interna (como Diawi, Firebase App Distribution o Microsoft App Center).

---

## 🛠️ Compilación Local por SSH o Mac Dedicada

Si tienes acceso a una máquina Mac física o en red local:
1. Clona el repositorio:
   ```bash
   git clone https://github.com/roysomoza/R_Music.git
   cd R_Music
   ```
2. Ejecuta el script de compilación automatizado:
   ```bash
   chmod +x scripts/build_ipa.sh
   ./scripts/build_ipa.sh
   ```
3. El archivo `.ipa` quedará listo en la ruta `build/ios_ipa/R_Music_v2.0.0.ipa`.
