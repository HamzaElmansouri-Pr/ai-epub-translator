# AI EPUB Translator 📖🌍

A cross-platform EPUB reader built with Flutter, designed specifically for language learners and bilingual readers. It seamlessly integrates advanced AI models to provide instant, context-aware translations directly while you read, eliminating the need to constantly switch between a book and a translation app.

## ✨ Current Features

### 🤖 Advanced AI Translation
* **Multiple AI Providers:** Choose between **OpenAI**, **Anthropic (Claude)**, **Google Gemini**, and **Groq** for high-quality translations.
* **Inline Translation:** Translate entire paragraphs or specific sentences inline, directly inside the book's text.
* **Bulk Translation Support:** Pre-translate sections of the book at once to save time while reading.

### 📚 Reading & Library Experience
* **EPUB Parsing:** Full support for importing and reading standard EPUB files.
* **Built-in Dictionary:** Highlight any word for instant dictionary definitions and context.
* **Text-to-Speech (TTS):** Listen to the pronunciation of foreign words, sentences, or let the app read entire paragraphs to you.
* **Bookmarks & Notes:** Save your progress, add bookmarks, and write down notes on specific passages.
* **Library Management:** Easily import books, view your reading progress, and manage your local library.

### ⚡ Performance & Efficiency
* **Translation Caching:** All translations are cached locally using SQLite. This saves significant API costs and makes revisiting translated pages instantaneous.
* **Cross-Platform:** Works beautifully on mobile (Android/iOS) and desktop (Windows/macOS/Linux).

---

## 🚀 Future Features (Roadmap)

We are constantly working to improve the reading and learning experience. Here is what's planned for the future:

- [ ] **Spaced Repetition System (SRS) & Flashcards:** Automatically extract highlighted words/phrases into a built-in flashcard system (similar to Anki) to build your vocabulary.
- [ ] **Cloud Syncing:** Sync your reading progress, bookmarks, notes, and translation cache across all your devices.
- [ ] **Additional Format Support:** Add support for reading PDF, MOBI, and other document formats.
- [ ] **Export Options:** Export your notes, highlights, and learned vocabulary to external tools like Notion, Obsidian, or CSV formats.
- [ ] **Offline AI Models:** Integration with local/offline LLMs (like Llama.cpp or MLC) for entirely private, on-device translation without API costs.
- [ ] **Audiobook / Sync-to-Text Mode:** Synchronized highlighting between professional audiobooks and text.

---

## 🛠️ Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (vers. 3.x+)
* An API key from one of our supported AI providers (OpenAI, Anthropic, Gemini, or Groq).

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/HamzaElmansouri-Pr/ai-epub-translator.git
   cd ai-epub-translator
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Environment Variables**
   Create a `.env` file in the root of the project and add your API keys:
   ```env
   OPENAI_API_KEY=your_openai_key_here
   CLAUDE_API_KEY=your_anthropic_key_here
   GEMINI_API_KEY=your_gemini_key_here
   GROQ_API_KEY=your_groq_key_here
   ```
   *(Note: The `.env` file is ignored by Git to protect your secrets.)*

4. **Run the app**
   ```bash
   flutter run
   ```

## 🤝 Contributing
Contributions are always welcome! Feel free to open an issue or submit a pull request if you'd like to help build new features or fix bugs.

## 📝 License
This project is open-source and available under the MIT License.
