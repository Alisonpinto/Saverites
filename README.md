# Memoria 🌌

Memoria is a premium, beautifully crafted social networking mobile application built with Flutter. It focuses on delivering a rich, media-first experience with a sleek dark-mode aesthetic, prioritizing user engagement through photo and video sharing, robust community safety tools, and seamless performance.

---

## ✨ Key Features

- **Media-Rich Feed**: Seamless scrolling through high-quality image and video posts with auto-playback and full-screen interactive viewing capabilities.
- **Premium Dark UI**: Carefully designed using an immersive dark theme matching modern iOS and Android premium app standards.
- **User Engagement**: Fully interactive posts allowing users to Like, Save, and Share content instantly.
- **Content Creation**: Integrated camera and gallery features allowing users to seamlessly capture and upload their own memories.
- **Community Safety**: Built-in "Report Post" feature that elegantly formats and launches an email to moderation teams, keeping the platform safe from harassment and spam.
- **Direct Feedback Integration**: In-app feedback system hooked directly to a serverless Google Apps Script webhook for real-time developer communication.
- **Local & Cloud Sync**: Employs robust local caching using `shared_preferences` with scalable data structures ready for Firebase/Firestore backend integration.
- **Smart Notifications**: Integrated local push notifications and app badging to keep users informed of interactions.

---

## 🛠 Tech Stack & Libraries

Memoria is built entirely in **Dart & Flutter**, utilizing a carefully curated set of packages to ensure maximum performance and native device integration:

- **UI & Styling**: `google_fonts` (Inter & Cascadia Code), `flutter_svg`, `dice_bear`
- **Media & Hardware**: `image_picker`, `video_player`, `file_picker`, `audioplayers`
- **State Management & Routing**: `get`, Custom Providers (`post_store`)
- **Networking & Intents**: `http` (for Webhooks & APIs), `url_launcher`, `share_plus`
- **Storage & Data**: `shared_preferences`
- **Device Integrations**: `flutter_local_notifications`, `app_badge_plus`, `flutter_contacts`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.11.5 or newer)
- Dart SDK
- Android Studio / Xcode (for emulation and building)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/memoria_flutter.git
   cd memoria_flutter
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Building for Production
To generate a release APK for Android:
```bash
flutter build apk --release
```
To generate an iOS build:
```bash
flutter build ios --release
```

---

## 🔒 Security & Moderation
Memoria takes community guidelines seriously. The integrated reporting tool automatically grabs the problematic Post ID, the precise timestamp, and the user's selected violation category, securely formatting it for the moderation team. 

---

## 👨‍💻 Developer Notes
The app utilizes an offline-first mock system via `jsonblob` and local storage to mimic backend behavior for rapid UI/UX prototyping. The data layer (`PostModel` and `UserPost`) is specifically structured to easily slot into a NoSQL database like Firebase Firestore with minimal refactoring.

---

## 👥 Meet the Team

**Developed by Arktech Developers**

- Alison Pinto
- Abhishek Kulbainur
- Aiden Rodrigues
- Jawaan Santh

*Made with ❤️ by Arktech Developers.*        
