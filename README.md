# PaintForge 🎨🔨

Inventario de pinturas para miniaturas, multiplataforma (Android, iOS y web), hecho con **Flutter**.

- **Catálogo integrado** con pinturas de **Citadel**, **Vallejo** (Model Color y Game Color), **The Army Painter** y **Green Stuff World**, con buscador por nombre, código y gama, y filtros por marca.
- **Mi inventario**: marca las pinturas que tienes y cuáles están **a punto de acabarse**.
- **Lista de compra** automática: las pinturas casi vacías y las que quieres comprar, con botón para copiarla al portapapeles.
- **Login** con correo/contraseña y **Google Sign-In** (Firebase Auth).
- **Sincronización en la nube** con Cloud Firestore (funciona también offline).
- **Interfaz en español e inglés** (según el idioma del sistema).
- **Preparada para anuncios de Google (AdMob)**, desactivados por defecto.

## Puesta en marcha

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.35+.

```bash
flutter pub get
flutter gen-l10n   # también se ejecuta automáticamente al compilar
flutter test
```

### 1. Configurar Firebase (obligatorio para login y sincronización)

La app compila sin configuración, pero arranca en modo "configuración pendiente" hasta que conectes tu proyecto de Firebase:

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Instala y ejecuta la CLI de FlutterFire desde la raíz del repo:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Esto regenera `lib/firebase_options.dart` (ahora es un placeholder) y descarga `google-services.json` / `GoogleService-Info.plist`.
3. En Firebase Console → **Authentication → Sign-in method**, activa **Email/Password** y **Google**.
4. En Firebase Console → **Firestore Database**, crea la base de datos y despliega las reglas incluidas:

   ```bash
   firebase deploy --only firestore:rules
   ```

#### Notas por plataforma

- **Android**: para Google Sign-In debes registrar la huella **SHA-1** de tu keystore en la configuración del proyecto de Firebase (Ajustes del proyecto → Tus apps → Añadir huella).
- **iOS**: en `ios/Runner/Info.plist` sustituye el placeholder `REVERSED_CLIENT_ID` por el valor real de tu `GoogleService-Info.plist`.
- **App Store**: si publicas en iOS con login de Google, Apple exige ofrecer también **Sign in with Apple**. No está implementado todavía; conviene añadirlo antes de publicar en la App Store.

### 2. Anuncios (AdMob) — opcional, desactivados por defecto

La integración con `google_mobile_ads` ya está hecha y probada con los IDs **de prueba** de Google. Para activarla:

1. Crea la app en [AdMob](https://admob.google.com/) y obtén tu **App ID** y tus **ad unit IDs**.
2. Sustituye los IDs de prueba:
   - App ID Android: `android/app/src/main/AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`).
   - App ID iOS: `ios/Runner/Info.plist` (`GADApplicationIdentifier`).
   - Ad units del banner: `lib/src/services/ads_service.dart`.
3. Compila con el flag:

   ```bash
   flutter run --dart-define=ENABLE_ADS=true
   ```

Sin el flag, la app no inicializa el SDK de anuncios ni muestra banners.

### 3. Ejecutar

```bash
flutter run                # dispositivo/emulador Android o iOS
flutter run -d chrome      # web
```

## Catálogo de pinturas

El catálogo vive en `assets/catalog/*.json` (un fichero por marca) y se empaqueta con la app, así que el buscador funciona sin conexión. Es un catálogo inicial representativo (~240 pinturas); para ampliar una marca basta con añadir entradas al JSON:

```json
{"id": "citadel-nuevo-color", "name": "Nuevo Color", "range": "Layer", "code": null, "hex": "#AABBCC"}
```

Los `id` deben ser únicos: son la clave con la que se guarda tu inventario en Firestore, así que no los cambies una vez en uso. Los colores `hex` son aproximados, para el swatch de la interfaz.

## Arquitectura

```
lib/
├── main.dart                  # arranque: Firebase, ads, catálogo
├── firebase_options.dart      # placeholder → lo genera flutterfire configure
├── l10n/                      # traducciones (app_en.arb, app_es.arb)
└── src/
    ├── app.dart               # MaterialApp, providers, auth gate
    ├── theme.dart             # Material 3, semilla naranja forja
    ├── models/                # Paint, InventoryEntry (estados)
    ├── data/                  # catálogo (assets) e inventario (Firestore)
    ├── services/              # AuthService, AdsService
    ├── state/                 # InventoryProvider (ChangeNotifier)
    ├── widgets/               # swatch, tiles, hoja de acciones, banner
    └── features/              # auth, catalog, inventory, shopping, settings
```

Estados de una pintura: **La tengo** (`inStock`), **Casi vacía** (`low`) y **Por comprar** (`wishlist`). La lista de compra son las dos últimas; el botón "Comprada" devuelve la pintura a `inStock`.

El inventario se guarda por usuario en `users/{uid}/inventory/{paintId}` y Firestore mantiene caché offline, así que la app funciona sin conexión y sincroniza al recuperar red.

## Tests

```bash
flutter test
```

Cubren la carga y búsqueda del catálogo, la lógica de inventario/lista de compra (con repositorio en memoria) y la pantalla de login (con autenticación falsa).
