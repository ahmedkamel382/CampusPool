# CampusPool 🚗🎓

**A secure, zero-commission, peer-to-peer carpooling mobile application engineered exclusively for the Arab Academy for Science, Technology & Maritime Transport (AASTMT) community.**

---

## 📖 About The Project

Urban mobility around university campuses often presents significant logistical and financial challenges. Students and faculty frequently face heavy traffic congestion, severe parking bottlenecks at the campus gates during morning peak hours, and the rising costs of commercial ride-hailing services.

**CampusPool** solves these problems by digitizing and securing the peer-to-peer carpooling experience. Operating on a strict zero-profit, cost-sharing model, the platform connects student drivers who have empty seats with riders traveling the exact same route. By strictly restricting platform access to verified institutional emails (`@student.aast.edu`), CampusPool creates a highly secure, closed-network ecosystem tailored for the AASTMT community.

## ✨ Key Features

* **Strict Institutional Security:** Registration and authentication are walled behind AASTMT email verification, ensuring that every user on the platform is a vetted colleague.
* **Atomic Seat Booking:** Utilizes NoSQL transactional logic to safely resolve race conditions. If multiple users request the final seat in a vehicle simultaneously, the system prevents data corruption and overbooking.
* **Real-Time Data Sync:** Powered by Firestore WebSockets, driver rosters, visual status badges, and seat availability metrics update instantly across all devices without requiring manual screen refreshes.
* **Hardware QR Boarding:** Replaces outdated verbal confirmations with a cryptographic QR digital ticket. The driver utilizes the device's native camera to physically scan and validate boarding passengers.
* **Geospatial Pin-Dropping:** Integrates OpenStreetMap tiles and `latlong2` for accurate, interactive pickup and drop-off coordinate mapping across Greater Cairo.
* **Smart UI Architecture:** Features a specialized "To/From Campus" binary data toggle. This architectural UI decision halves database read operations, optimizing cloud performance and minimizing user cognitive load.
* **Cultural & Comfort Filters:** Includes an algorithmic "Same Gender Only" database toggle, providing female students with an additional layer of psychological safety and comfort.

## 🏗️ System Architecture

CampusPool relies on a modern, decoupled client-server architecture designed for zero-budget cloud constraints:

* **The Frontend (Flutter/Dart):** Compiled to native ARM machine code for both iOS and Android. It utilizes the `Provider` pattern for reactive state management, caching user locations locally to prevent redundant network calls.
* **The Backend (Firebase NoSQL):** Leverages Cloud Firestore with strict document denormalization. Rider data (like profile images and phone numbers) is copied directly into the `Ride` document's `passengerRoster` map, ensuring the driver's UI can render all necessary data with a single, highly efficient database read.
* **Native Platform Bridging:** Custom configurations in the `AndroidManifest.xml` and iOS `Info.plist` bridge the Flutter Dart code with native OS permissions, allowing secure access to the camera (`mobile_scanner`) and gallery (`image_cropper`).

## 🛠️ Technology Stack

* **Frontend Engine:** Flutter SDK (Dart)
* **Backend Infrastructure:** Google Firebase (Spark Free-Tier)
    * Firebase Authentication
    * Cloud Firestore
* **State Management:** `provider`
* **Geospatial Tools:** `flutter_map`, `latlong2`, OpenStreetMap
* **Hardware Integrations:** `mobile_scanner`, `image_picker`, `image_cropper`

## 🚀 Getting Started

To compile and run this project locally, you will need the Flutter SDK installed and a properly configured Firebase environment.

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.0 or higher recommended)
* Dart SDK
* An IDE (VS Code or Android Studio)
* A physical mobile device or configured Emulator (Android API 33+ / iOS 14+)

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/campuspool.git](https://github.com/your-username/campuspool.git)
   cd campuspool
   
2. **Install Flutter packages:**
   ```bash
   flutter pub get

3. **Configure Firebase:**
* Create a new project in the Firebase Console.
* Register your Android and iOS applications within the console.
* Download the `google-services.json` and place it in the `android/app/` directory.
* Download the `GoogleService-Info.plist` and place it in the `ios/Runner/` directory.

4. **Configure Firebase:**
    ```bash
   flutter run

## 🧪 Testing & Quality Assurance

The system underwent rigorous black-box integration testing on physical hardware to ensure stability. Key testing milestones included:

* **Concurrency Validation:** Successfully tested Atomic Transactions to prevent overbooking during simultaneous seat requests.
* **Hardware Permission Testing:** Verified native camera (`NSCameraUsageDescription`) and storage integration across both Apple iOS and Android environments.
* **Pagination & Read Limits:** Confirmed that UI-level directional filters successfully cut Firebase document payload sizes in half.

## 🔭 Future Scope

While the current production release successfully meets all baseline requirements, the highly modular architecture allows for significant future enhancements:

* **Live Telemetry:** Upgrading from static map pins to live Google Maps GPS tracking for approaching drivers.
* **Inter-Campus Routing:** Expanding the database schema to support trips between the New Cairo, Smart Village, and Alexandria AASTMT branches.
* **Automated Fare Splitting:** Integrating third-party digital payment gateways (e.g., Paymob) for zero-friction wallet deductions upon QR scan.

## 👥 Meet the Team

Developed as a Final Project for the Mobile Applications Course (2025-2026) at AASTMT College of Engineering.

**Development Team:**
* Ahmed Khalid Mohamed
* Bassel Adel
* Mohamed Haitham
* Karim Hossam
* Omar Bekhiet
* Fady Ashraf Edwar

**Academic Supervisors:**
* Assoc. Prof. Dr. Ahmed Maher
* Eng. Heba Fathy

---
*Built with ❤️ and ☕ in Cairo, Egypt.*
