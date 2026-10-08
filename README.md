# Krishi Karobar

**Krishi Karobar** is a comprehensive Flutter mobile application designed for recording and managing day-to-day agricultural-service operations. It centralizes vehicle tracking, customer records, service management, activity monitoring, expense tracking, billing receipts, and periodic financial reporting into a single platform.

The application is developed for **Prasanna Aadhunik Krishi Kendra** to streamline agricultural service operations, real-time activity monitoring, and payment workflows.

---

## 🚀 Key Features & Recent Updates

### 🚜 Vehicle & Activity Management
- **Vehicle & Service Selection**: Assign vehicles, drivers, and supervisors with persistent user session caching (`recentVehicleIds`).
- **GPS Location Tracking**: Capture start/stop GPS locations for activities with Admin-only access rules and reverse geocoding for place names.
- **Manual GPS Tagging**: Support manual GPS tagging for both Activity and Expense creation forms.
- **Activity State Management**: Real-time tracking of running, paused, and completed activities, with soft-reset/cancellation (`status = 'cancelled'`) preserving audit trails.

### 👥 Customer & Search Enhancements
- **Customer Search & Autocomplete**: Real-time search suggestions with auto-fill for customer names, phone numbers, and addresses across forms.

### 💰 Financials, Billing & Expenses
- **Discount & Due Calculation**: Dedicated discount tracking (`discountAmount`) across activities, expenses, and payments.
- **View Bill & Multi-Activity Payment Slips**: Generate and view detailed payment receipts (`PaymentSlip`) supporting multi-activity payment allocations in a single transaction.
- **Expense Table & Details**: Comprehensive expense management with row selection, type filters, and detail views.

### 📊 Dashboard & Periodic Reporting
- **Periodic Reports**: Daily, Weekly, Monthly (Bikram Sambat), and Yearly Income, Expense, and Net Profit/Loss summaries.
- **Vehicle-Filtered Dashboards**: Dashboard reports automatically filter by the vehicle selected in Settings (or locked to the single assigned vehicle for normal users).

### 🔒 Security & Synchronization
- **Role-Based Authorization**: Granular permissions for Admins, Managers, Supervisors, Drivers, and Accountants.
- **Firebase Real-Time DB**: Real-time data synchronization with robust offline caching and session management.

---

## 🛠️ Technology Stack

- [Flutter](https://flutter.dev/) & Dart
- Firebase Authentication & Firebase Realtime Database
- GetX (State Management & Navigation)
- Get Storage & SharedPreferences (Local Caching)
- Nepali Utils & Nepali Date Picker (Bikram Sambat & NPT support)

---

## 📦 Getting Started

### Prerequisites

- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Set up an Android emulator/device or target
- Configure Firebase credentials (`google-services.json`)

### Run Locally

```bash
git clone https://github.com/prasannakrishi/krishi_karobar.git
cd krishi_karobar
flutter pub get
flutter run
```

---

## 📁 Project Structure

```text
lib/
├── common/         # Shared widgets (Customer search, App scaffolds, etc.)
├── features/       # Feature modules:
│   ├── activity_monitor/ # Live activity timer, GPS tracking, vehicle/customer info
│   ├── authentication/   # Login, session management, and auth gates
│   ├── home/             # Dashboard periodic reporting & vehicle summaries
│   ├── payment/          # Payment dialogs, allocations, and bill slips
│   ├── payment_history/  # Historical payment records and summaries
│   ├── recent_activity/  # Activity logs, tables, edit forms, and expenses
│   └── user_setting/     # User, vehicle, customer, and service management screens
├── models/         # Data models (Activity, Customer, Expense, Payment, Vehicle, User, etc.)
├── offline/        # Offline sync adapters
├── services/       # Firebase, caching, audit, and authorization services
├── utils/          # Themes, helpers, constants, validation, and exceptions
└── widgets/        # Core UI building blocks
```

---

## 📄 License

This project is private and maintained exclusively for **Prasanna Aadhunik Krishi Kendra**.
