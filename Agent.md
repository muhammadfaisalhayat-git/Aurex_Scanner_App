# Aurex Scanner Project Agent Context

## Project Overview
- **Name:** Aurex Scanner
- **Type:** Flutter / Android
- **Objective:** Premium cross-platform scanner for Lafi AL Harbi Group & Bin Awf.
- **Key Technologies:** Flutter, Firebase (Auth, Database, Firestore), Google ML Kit (OCR & Barcode), SQLite (sqflite).

## Foundational Architecture
- **Philosophy:** Adhere to Clean Architecture and Repository Pattern.
- **State Management:** Provider / ChangeNotifiers.
- **Persistence:** Offline-first with local SQLite (sqflite) and Firebase Realtime Database sync.

## Standards & Best Practices
- **UI:** Material 3 design, stateless widgets where possible, performant lists.
- **Concurrency:** Dart Async/Await, Kotlin Coroutines for Android native code.
- **Android Native:** Clean Kotlin, ViewBinding (if XML), and Hilt for DI in native modules.
- **Firebase:** Centralized initialization and error handling.

## Development Environment
- **Minimum SDK (Android):** 21
- **Target SDK (Android):** 34
- **Flutter Version:** 3.44.0
