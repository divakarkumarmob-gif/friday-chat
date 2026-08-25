# Friday Chat - WhatsApp-like Flutter Messaging App

A modern, production-ready Flutter messaging application built following **Clean Architecture** principles, featuring WhatsApp-styled light and dark themes, declarative routing via `go_router`, and responsive UI screens.

---

## 🏛️ Clean Architecture Project Structure

The project strictly adheres to Uncle Bob's Clean Architecture pattern, dividing concerns into **Domain**, **Data**, and **Presentation** layers across feature modules, along with a shared **Core** module.

```
lib/
├── main.dart                               # App entry point, DI setup & ThemeProvider
├── core/
│   ├── constants/                          # Global string and asset constants
│   ├── error/                              # Failure and Exception abstractions
│   ├── router/                             # GoRouter configuration & page transitions
│   ├── theme/                              # Light/Dark Theme, Colors, Typography
│   ├── usecase/                            # Abstract base UseCase<Type, Params>
│   └── widgets/                            # Reusable widgets (UserAvatar, StatusBadge)
└── features/
    ├── dashboard/
    │   └── presentation/
    │       └── screens/
    │           └── dashboard_screen.dart   # WhatsApp AppBar, Tabs, Dynamic FAB
    ├── chat/
    │   ├── domain/
    │   │   ├── entities/                   # ChatMessage, ChatConversation
    │   │   ├── repositories/               # ChatRepository contract
    │   │   └── usecases/                   # GetConversations, GetMessages, SendMessage
    │   ├── data/
    │   │   ├── models/                     # JSON serializable models
    │   │   ├── datasources/                # ChatMockDataSource
    │   │   └── repositories/               # ChatRepositoryImpl
    │   └── presentation/
    │       ├── providers/                  # ChatProvider (ChangeNotifier)
    │       ├── screens/
    │       │   ├── chats_tab.dart          # Recent chats list with unread badges
    │       │   └── chat_room_screen.dart   # Interactive chat room with speech bubbles
    │       └── widgets/
    │           ├── chat_tile.dart
    │           ├── message_bubble.dart
    │           ├── chat_input_bar.dart
    │           └── attachment_bottom_sheet.dart
    ├── call/
    │   ├── domain/
    │   │   ├── entities/                   # CallLog (Audio/Video, Incoming/Outgoing/Missed)
    │   │   ├── repositories/               # CallRepository contract
    │   │   └── usecases/                   # GetCallLogs
    │   ├── data/
    │   │   ├── models/                     # CallLogModel
    │   │   ├── datasources/                # CallMockDataSource
    │   │   └── repositories/               # CallRepositoryImpl
    │   └── presentation/
    │       ├── providers/                  # CallProvider
    │       ├── screens/
    │       │   ├── calls_tab.dart          # Call history & "Create call link"
    │       │   └── calling_screen.dart     # Fullscreen calling UI (Audio & Video)
    │       └── widgets/
    │           ├── call_tile.dart
    │           └── call_action_button.dart
    └── contacts/
        ├── domain/
        │   ├── entities/                   # Contact entity
        │   ├── repositories/               # ContactsRepository contract
        │   └── usecases/                   # GetContacts
        ├── data/
        │   ├── models/                     # ContactModel
        │   ├── datasources/                # ContactsMockDataSource
        │   └── repositories/               # ContactsRepositoryImpl
        └── presentation/
            ├── providers/                  # ContactsProvider
            ├── screens/
            │   └── contacts_tab.dart       # Contacts directory with direct chat/call
            └── widgets/
                └── contact_tile.dart
```

---

## 🎨 Themes & Design System

- **WhatsApp Palette**: Emerald Teal (`#00A884`, `#008069`), WhatsApp Green (`#25D366`), Chat Background (`#EFEAE2` light / `#0B141A` dark).
- **Message Bubbles**: Outgoing bubble styling with tails, delivery status ticks (sent, delivered, read double blue checkmarks), and localized timestamps.
- **Theme Toggle**: Live Dark/Light mode switcher available directly in the dashboard header.

---

## 🚀 How to Run

1. Make sure Flutter SDK is installed and added to your `PATH`.
2. Get packages:
   ```bash
   flutter pub get
   ```
3. Run the app on an emulator, device, or web:
   ```bash
   flutter run
   ```

---

## 📱 Implemented Screens

1. **Dashboard (`DashboardScreen`)**:
   - TabBar with **Chats**, **Calls**, and **Contacts**.
   - Search button, camera trigger, theme toggle, and overflow menu.
   - Dynamic FAB that changes action according to the selected tab.
2. **Chat Room (`ChatRoomScreen`)**:
   - Custom top bar with user profile avatar, name, and live online/offline indicator.
   - Header action buttons for Voice and Video Calling.
   - End-to-end encrypted notification banner.
   - Message list with speech bubble tails and message delivery statuses.
   - Rich input bar with emoji trigger, camera, attachment modal sheet, dynamic mic/send button.
3. **Calling Screen (`CallingScreen`)**:
   - Supports both **Voice** and **Video** calls.
   - Animated pulsing caller avatar.
   - Call duration timer with auto-connection simulation.
   - Full in-call control bar: Speaker toggle, Video toggle, Mic mute, Front/Back camera flip, and End Call button.
