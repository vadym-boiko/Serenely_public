
# Serenely – Reflective AI Coach for Everyday Mental Health

Serenely is an iOS app that helps you reflect on your day, get a short session summary, and turn insights into small, practical tasks.
It’s built with **SwiftUI**, **Combine**, **Core Data** and the **OpenAI GPT API**, and fully localized for **English** and **Ukrainian**.

⚠️ This repository is a demo/version for review. Real API keys and other secrets are **not** included.

Features

 🧠 **AI Reflection Chat**
     Talk to an empathetic assistant about how you feel. The app sends your messages to the OpenAI API and shows short, supportive replies.
        
 🧾 **Session Summary**
     At the end of a conversation, Serenely asks the model to generate a concise session summary (4–7 sentences) tailored to the user’s context.
 
 ✅ **Actionable Tasks**    
     The model suggests up to 7 small, concrete tasks. In the UI you can:  - mark tasks as **Done**, **Skip**, or **Delete** via swipe actions,  - move completed/ignored tasks          into **History**,  - restore or delete tasks from history.
 
 ⭐️ **Usefulness Rating**    
     After you mark a task as done, a bottom sheet appears where you can quickly rate how useful the task was. When you tap **“Done”**, the app: - saves the usefulness rating,  -       moves the task into history,  - uses this feedback to update the long‑term user portrait.
 
 👤 **Personal Portrait**    
     A dedicated **Portrait** screen shows:  - a short written summary of the user’s current situation,  - focus areas and helpful strategies (e.g. “short walks”, “breathing            exercises”),  - simple stats about suggested/completed/skipped tasks.    The portrait is updated after each session using `PortraitDelta` + a secondary `regeneratePortrait`        call to the model.
     
 🌐 **Localization & Language‑Aware AI**
    UI is localized to **English** and **Ukrainian** using `Localizable.strings` and a small `LocalizationManager`.    - A language switcher (UK/EN) on the Portrait screen lets        the user change app language at runtime.    - Chat & summaries are generated in the active language; the GPT system prompts adapt automatically.---## 

 ## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI (NavigationStack, custom gestures, animations)
- **State & Reactivity:** Combine, `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- **Persistence:** Core Data (`UserPortraitEntity`, `PendingTaskEntity`), AppStorage
- **Networking:** URLSession, JSON / Codable, OpenAI GPT API, OpenWeather API (for experiments)
- **System APIs:** CoreLocation (for Weather demo), UIKit interop (keyboard handling)
- **Tooling:** Xcode, Swift Package Manager, App Store Connect, TestFlight   

## Project Structure

Serenely/
├── SerenelyApp.swift          # App entry point, DI with EnvironmentObjects
├── CoreData/                  # CoreDataStore, PersistenceController, NSManagedObject subclasses
├── Models/                    # ActionTask, TaskStatus, UserPortrait, SessionHighlights, TabNavigationHelper
├── Services/
│   └── GPTService.swift       # OpenAI API integration (sendMessage, finalizeSession, regeneratePortrait, streamChat)
├── Support/
│   └── Localization.swift     # AppLanguage, L10n helper, LocalizationManager
├── ViewModel/
│   ├── TherapyChatViewModel.swift
│   └── TasksViewModel.swift
├── View/
│   ├── MainTabView.swift
│   ├── LaunchView.swift
│   ├── TherapyChatView.swift
│   ├── TasksView.swift + swipe rows
│   ├── SummarySheetView.swift
│   ├── PortraitView.swift
│   ├── Common/
│   │   ├── UIComponents.swift
│   │   └── UsefulnessPickerSheet.swift
│   └── Theme.swift            # Colors, fonts, reusable styles
└── Utilities/
    ├── KeyboardWarmer.swift
    └── TaskStoreWarmer.swift    
    
