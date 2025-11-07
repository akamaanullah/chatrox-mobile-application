# Chatrox – Real-Time Team Messaging

Chatrox is a cross-platform collaboration suite built with Flutter. It delivers secure direct messaging, rich media conversations, and channel-based teamwork for companies that need a branded, self-hosted alternative to mainstream chat apps.

## Feature Highlights

- **Secure authentication & onboarding** – Supports login, logout, password reset, and profile management through the REST endpoints defined in `lib/config/api_config.dart`.
- **Modern home experience** – Recent conversations with search, unread indicators, and a quick camera shortcut for instant media sharing.
- **Rich private messaging** – Emoji & GIF picker, message editing, threaded replies, file uploads, PDF viewing, forwarding, reactions, and read receipts.
- **Channel collaboration** – Public/private channels, join approvals, member management, announcements, and channel-specific messaging.
- **Activity center & notifications** – Unified feed for mentions, join requests, and announcements plus local push notifications via `NotificationService` (ready to switch to WebSockets when the backend exposes them).
- **Cross-platform delivery** – Android, iOS, web, macOS, Windows, and Linux builds share the same Material 3 themed interface and responsive layouts.

## Architecture Overview

- **Flutter + Material 3 UI** with a shared theme in `lib/constants/theme.dart` and modular widgets/components.
- **REST API integration** centralised in `ApiConfig`, with `services/` handling HTTP requests and response parsing.
- **Persistent storage** for auth/session data handled by `lib/utils/storage.dart` (wrapping `SharedPreferences`).
- **Local notifications** managed by `lib/services/notification_service.dart`, currently polling endpoints while the WebSocket rollout is finalised.
- **Feature modules**: `screens/` encapsulates flows for chats, channels, activities, settings, PDF viewing, etc., keeping business logic scoped per screen.

```
lib/
  config/            // API endpoints & environment switching
  constants/        // Theme and design tokens
  models/           // Typed data models for chats, channels, users
  screens/          // UI flows (auth, chat, activity, settings, etc.)
  services/         // REST integrations, notification service
  widgets/          // Reusable UI components
```

## Getting Started

1. **Prerequisites**
   - Flutter 3.19+ (verify with `flutter --version`)
   - A running Chatrox API backend (PHP endpoints referenced in `ApiConfig`)
   - Android/iOS tooling if you plan to build mobile binaries

2. **Clone & install dependencies**
   ```bash
   git clone git@github.com:akamaanuallah/chatrox-mobile-application.git
   cd chatrox-mobile-application
   flutter pub get
   ```

3. **Configure environment**
   - Update the base URLs inside `lib/config/api_config.dart` to match your backend.
   - Place any private keys (Firebase, signing configs, etc.) outside the repo or load them via environment variables. Files such as `google-services.json` are intentionally ignored by `.gitignore`.

4. **Run the app**
   ```bash
   flutter run                     # Auto-detects a connected device or simulator
   flutter run -d chrome           # Web preview
   flutter run -d windows|macos    # Desktop preview
   ```

5. **Execute automated tests**
   ```bash
   flutter test
   ```

## Security & Compliance Notes

- Never commit secrets, API tokens, or signing assets. Use encrypted storage or your CI/CD secret manager.
- `.gitignore` already excludes build outputs, Gradle properties, keystores, and Google service configs—double-check before pushing.
- When migrating to true real-time updates, prefer WebSocket channels over polling to align with the architectural direction documented in `WEBSOCKET_IMPLEMENTATION_STATUS.md`.

## Contact

- Website: [amaanullah.com](https://amaanullah.com)
- Email: [info@amaanullah.com](mailto:info@amaanullah.com)

For project-specific inquiries or support, reach out via the contact channels above.
