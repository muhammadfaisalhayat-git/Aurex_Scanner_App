---
name: android-architecture-standards
description: Expert instructions for maintaining Clean Architecture, Repository patterns, and modern state management in the Android/Flutter context.
---

# Android Architecture & Agent Instructions

When generating or refactoring code for this project, adhere to the following expert rules:

## 1. Clean Architecture
- Maintain clear separation between **Data**, **Domain**, and **UI** layers.
- For Android native modules, use **Hilt** for Dependency Injection.
- For Flutter modules, use **Provider** for dependency management.

## 2. State Management
- Native Android: Use `ViewModel` with `StateFlow` and `SharedFlow`. Avoid mutable state in the View layer.
- Flutter: Use `ChangeNotifier` or `StatefulWidget` (if local) with clear separation of business logic.

## 3. Data Layer & Repository Pattern
- Implement an **Offline-First** approach.
- Always use the **Repository Pattern** to abstract data sources (SQLite, Firebase, ERP API).
- Ensure all network calls have proper error handling and retry logic.

## 4. Jetpack Compose (Native)
- Use **stateless Composables**.
- Implement type-safe navigation.
- Audit for "recomposition storms" and optimize layout performance.

## 5. Concurrency
- Native: Use Kotlin Coroutines with appropriate Dispatchers (`Dispatchers.IO` for DB/Network).
- Flutter: Use `Future` and `Stream` with `async/await`. Avoid blocking the UI thread.

## 6. Testing Philosophy
- Unit tests for all business logic.
- Integration tests for Repository sync logic.
- Screenshot testing for critical UI flows.
