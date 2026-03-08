# Anything

**Anything** is an AI-first Flutter application. Unlike traditional apps where users navigate through hardcoded menus and buttons, *Anything* allows you to express your intent natively through natural language. The app dynamically assembles the interface, tools, and widgets you need in real-time.

## Features

- **Generative UI (AUIL)**: *Anything UI Language* translates AI reasoning directly into native Flutter components (e.g., charts, metric cards, tables, and text blocks) dynamically on the fly.
- **Groq Integration**: Lightning-fast inference via the Groq API, using state-of-the-art open models like `openai/gpt-oss-120b` and `gemma2-9b-it`.
- **Kaalka Time-Key Security**: User data and context memory are encrypted locally using time-derived encryption keys via the `kaalka` package, ensuring your local memory is secure without relying on cloud storage.
- **Context Engine**: A smart memory manager built on SQLite that learns your workflows and preferences locally, securely encrypted for privacy.
- **AI Command Bar**: The central hub for all interaction. Just type what you want to achieve, and the app decides what tools to run and what UI to render.

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: `flutter_riverpod`
- **Generative AI Inference**: `http` (targeting Groq API)
- **Local Database**: `sqflite`
- **Security / Encryption**: `kaalka` & `flutter_secure_storage`
- **Data Visualization**: `fl_chart`

## Getting Started

### Prerequisites
- Flutter SDK (`^3.9.2` or later)
- A valid [Groq API Key](https://console.groq.com/keys)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
   cd Anything
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

### Configuration

When you first launch the app, you will be taken through the onboarding process. 
1. Navigate to **Settings > Groq AI Configuration** to enter and validate your Groq API key.
2. Navigate to **Settings > Kaalka Security** to configure your local time-key encryption settings.

## Project Structure

- `lib/core/`: Contains the logic for the context engine, intent engine, and reasoning engine.
- `lib/models/`: Contains data structures, such as the `AUILSchema`.
- `lib/memory/`: SQLite service and memory manager for storing conversational data.
- `lib/screens/`: Flutter UI screens (Settings, Workspaces, Onboarding, etc.).
- `lib/security/`: Integration with the Kaalka encryption package and secure storage.
- `lib/services/`: External API integrations, primarily the `GroqService`.
- `lib/ui_engine/`: The core of the Generative UI system. Parses AUIL JSON and renders native Flutter widgets via the `ComponentRegistry` and `LayoutEngine`.
- `lib/widgets/`: Reusable native widgets like the AI Command Bar and Loading Screen.

## Contributing

Contributions, issues, and feature requests are welcome!
