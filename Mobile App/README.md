# flutter_starter

A new Flutter project.

## Getting Started

- Install [Fvm](https://fvm.app/docs/getting_started/installation).

- Go to this project folder and run `fvm install` to install the correctsponding Flutter SDK version.

> If you are not using Fvm, make sure your Flutter version in your local machine matched with the `.fvm/fvm_config.json`

- Run `flutter doctor` and make sure that there is no error occurred.

> This project is optimized for [Visual Studio Code](https://code.visualstudio.com/) users

## Developing

### Running the app

- Start the backend, then run the dev flavor with its API base URL. Android
  emulator uses the default `http://10.0.2.2:8080/api/v1/`; override it for a
  physical device or desktop build:

```bash
flutter run --flavor=dev -t lib/main_dev.dart \
  --dart-define=API_BASE_URL=http://192.168.100.153:8080/api/v1/
```

- Run `flutter run --flavor=staging -t lib/main_staging.dart` to run the app in staging environment.
- Run `flutter run --flavor=production -t lib/main_production.dart` to run the app in production environment.

Authentication tokens are stored with `flutter_secure_storage`. The network
client refreshes an expired access token once, retries the original request,
and clears the local session if refresh rotation fails or token reuse is
reported by the backend.

### When adding a new translated text

- Add the translated text to `lib/presenter/languages/translations/<langualge>.json`

- Run this script to generate the translation keys

```bash
flutter pub run easy_localization:generate \
  -f keys \
  -S lib/presenter/languages/translations \
  -O lib/presenter/languages \
  -o translation_keys.g.dart
```

> If you are using Visual Studio Code, you can run this script by pressing `Cmd + Shift + P` and type `Run Task` and select `easy_localization: generate keys`

### When adding new page

- Run this script to activate `mason_cli` (if you haven't done it before)

```bash
flutter pub global activate mason_cli
mason get
```

- Run this script to generate a new page with basic cubit

```bash
mason make bloc_page
```

> If you are using Visual Studio Code, you can run this script by pressing `Cmd + Shift + P` and type `Run Task` and select `mason: bloc_page`
