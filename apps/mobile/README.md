# 📱 EcoCampus Mobile Application

The student-facing mobile application for the **EcoCampus** platform, built with **Flutter**, **Dart**, and **Riverpod**.

---

## 🌟 Key Features

- **Issue Reporting:** Camera and gallery image picker with compression, GPS location geotagging, and snapping to campus landmarks.
- **AI Classification Assistance:** Integrates with Supabase Edge Functions & Google Gemini to auto-suggest issue categories, severities, and routing.
- **Campus Issues Feed:** Browse reported campus issues with dynamic signed URL image loading and responsive placeholders.
- **Issue Tracking:** Live status timeline (`REPORTED` $\rightarrow$ `ASSIGNED` $\rightarrow$ `IN_PROGRESS` $\rightarrow$ `RESOLVED`).
- **Interactive Campus Map:** 2D interactive campus map with pinned issues and building sustainability scores.
- **Gamification:** EcoPoints balance, streak tracking, daily challenges, and achievement badges.
- **Notices & Push Notifications:** Campus-wide sustainability alerts and status update notifications via Firebase Cloud Messaging.

---

## 🛠️ Tech Stack & Dependencies

- **Framework:** Flutter SDK `^3.7.2`
- **State Management:** `flutter_riverpod: ^3.3.2`
- **Backend & Auth:** `supabase_flutter: ^2.15.4`
- **Location:** `geolocator: ^14.0.2`
- **Media:** `image_picker: ^1.1.2`
- **Typography & UI:** `google_fonts: ^6.3.2`, `cupertino_icons: ^1.0.8`
- **Notifications:** `firebase_core`, `firebase_messaging`, `flutter_local_notifications`

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Backend Credentials
Verify `lib/core/constants/supabase_constants.dart` points to your active Supabase instance:
```dart
const String supabaseUrl = 'https://<your-project-ref>.supabase.co';
const String supabaseAnonKey = '<your-anon-key>';
```

### 3. Run the App
```bash
# Debug mode on connected device or emulator
flutter run
```

---

## 🧪 Testing

```bash
# Run unit and widget test suite
flutter test

# Run static analysis
flutter analyze
```
