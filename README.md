# Krishi Karobar

**Krishi Karobar** is a Flutter application for recording and managing day-to-day agricultural-service operations. It helps a team keep vehicle, customer, service, activity, and payment information in one place.

The application is developed for **Prasanna Aadhunik Krishi Kendra** and is intended to support clearer operational records and easier follow-up on agricultural service activities.

## Key features

- Phone-based user registration and login
- User roles for Driver, Supervisor, Staff, and Admin
- Vehicle registration, selection, and driver/supervisor assignment
- Customer and service record management
- Activity monitoring with vehicle, customer, driver, service, duration, and amount details
- Payment tracking, including paid and due amounts
- Activity history with filters for date, vehicle, customer, staff, and service
- Real-time data synchronization with Firebase Realtime Database
- Local data caching for faster access during normal use

## About Prasanna Aadhunik Krishi Kendra

Prasanna Aadhunik Krishi Kendra is the operating organization for this application. Krishi Karobar is built to organize the Kendra's service-related vehicle activities, customer records, service entries, and payment follow-up in a consistent digital system.

## Technology

- [Flutter](https://flutter.dev/) and Dart
- Firebase Authentication
- Firebase Realtime Database
- GetX for state management and navigation
- Shared Preferences and Get Storage for local storage

## Getting started

### Prerequisites

- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Set up an Android emulator/device or another supported Flutter target
- Configure access to the project's Firebase instance

### Run locally

```bash
git clone https://github.com/prasannakrishi/krishi_karobar.git
cd krishi_karobar
flutter pub get
flutter run
```

## Project structure

```text
lib/
├── features/       # Authentication, home, monitoring, history, and settings screens
├── models/         # User, vehicle, customer, service, and activity data models
├── services/       # Firebase and local cache services
├── utils/          # Themes, helpers, constants, validation, and exceptions
└── widgets/        # Shared UI widgets
```

## Development notes

- Do not commit private credentials, API keys, or environment files to the repository.
- Review Firebase Authentication and Realtime Database rules before releasing the application.
- Run `flutter analyze` and `flutter test` before creating a production build.

## License

This project is private and maintained for Prasanna Aadhunik Krishi Kendra.
