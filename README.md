# 💚 NaikiApp — Local Food Donation & NGO Connector

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev) [![Firebase](https://img.shields.io/badge/Firebase-Realtime%20DB-yellow?logo=firebase)](https://firebase.google.com) [![License](https://img.shields.io/badge/License-MIT-green)](#-license)

> A real-world Flutter app that helps donors post surplus food and NGOs claim nearby donations using OTP login, live location, and Firebase data.

---

## 📱 Features

### 🧑‍🌾 Donor Flow
- Login with phone-based OTP.
- Choose donor or NGO role.
- Post food donations with title, quantity, description, expiry window, and optional anonymity.
- Share real-time GPS location with each donation.
- View donation history and status updates.

### 🏥 NGO Flow
- Discover available donations within a 5 km radius.
- Inspect donation locations using Google Maps markers.
- Claim food donations safely using Firebase transaction control.
- Track claimed collections in a dedicated view.

### 🌍 Shared Features
- Persistent session storage via `shared_preferences`.
- Firebase Realtime Database for live updates.
- Material 3-inspired theme and responsive UI.
- Location permission handling for accurate donor and NGO experiences.

---

## 🛠️ Tech Stack

| Category | Technology |
| --- | --- |
| Framework | Flutter |
| Language | Dart |
| State Management | Provider |
| Auth | Firebase Auth (OTP) |
| Database | Firebase Realtime Database |
| Location | geolocator |
| Maps | google_maps_flutter |
| Notifications | flutter_local_notifications |
| Local Storage | shared_preferences |
| UI | google_fonts, Material 3 |
| Utilities | permission_handler, cached_network_image, intl |

---

## 📂 Project Structure

```text
lib/
├── main.dart                    # App entry point and Firebase initialization
├── firebase_options.dart        # Firebase configuration file
├── core/
│   ├── config/                  # Auth and app configuration
│   ├── providers/               # App state management providers
│   └── utils/                   # Shared utility classes
├── features/
│   ├── auth/                    # Login, registration, splash screen
│   ├── donor/                   # Donor dashboard and donation posting
│   └── ngo/                     # NGO dashboard, map view, and claims
└── services/                    # Firebase service wrappers
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter installed and configured
- Android Studio or Visual Studio Code
- Android emulator / iOS simulator or physical device
- Firebase project setup for your app

### Installation

1. Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/naiki_app.git
cd naiki_app
```

2. Install dependencies:

```bash
flutter pub get
```

3. Configure Firebase:
- Add `google-services.json` to `android/app/`
- Add `GoogleService-Info.plist` to `ios/Runner/`
- Ensure `lib/firebase_options.dart` is generated for your Firebase project

4. Run the app:

```bash
flutter run
```

---

## 🏗️ Architecture

NaikiApp follows a clean **Provider + Service** architecture:

- **Screens** — UI and navigation logic
- **Providers** — State management and session handling
- **Services** — Firebase and business logic
- **Config** — App settings and auth behavior

---

## 📊 App Screens

| Screen | Description |
| --- | --- |
| Splash Screen | Animated launch with session restore and role-based navigation |
| Login Screen | Phone OTP login with donor/NGO role selection |
| Register Screen | Donor / NGO registration flow |
| Donor Dashboard | Post donations and view personal donation history |
| NGO Dashboard | View nearby donations, map markers, and claim requests |

---

## 🔑 Key Technical Highlights

- **OTP-Based Login** — Secure phone authentication using Firebase
- **Live Location Posting** — Donors attach GPS coordinates to donation entries
- **Nearby Donation Discovery** — NGOs find food options within 5 km
- **Atomic Claim Handling** — Firebase transaction claims prevent duplicate pickups
- **Persistent Session** — Keep users logged in with shared preferences
- **Modern UI** — Responsive Material 3 styling with polished card and input design

---

## 👩‍💻 About the Developer

**Sawaira Tanveer**
Mobile Application Developer | Flutter & Android

- 🎓 BS Computer Science
- 💼 Experience with Flutter, Native Android (Java), Ionic, Firebase
- 📍 Gujrat, Pakistan

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](www.linkedin.com/in/sawaira-tanveer-433224324)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?logo=github)](https://github.com/sawairatanveer10)


---

## 📄 License

This project is licensed under the MIT License.

---

<p align="center">Made with ❤️ by Sawaira Tanveer</p>