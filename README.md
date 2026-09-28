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

# Architecture Report — EPub Translate Meaning

> **Version:** 1.0.0  
> **Last Updated:** September 2026  
> **Platform:** Flutter (Android, iOS, Linux, macOS, Windows, Web)

---

## 1. Overview

**EPub Translate Meaning** is a cross-platform Flutter application that enables users to import, read, and translate EPUB and PDF books using multiple AI-powered translation providers. The app follows **Clean Architecture** principles with a feature-first modular structure and uses the **BLoC/Cubit** pattern for state management, **GetIt + Injectable** for dependency injection, and **GoRouter** for declarative navigation.

---

## 2. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Library  │ │  Reader  │ │Translate │ │Dictionary│ │ Settings │ │
│  │  Cubit   │ │  Cubit   │ │  Cubit   │ │  Cubit   │ │  Cubit   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│       │             │            │             │            │       │
├───────┼─────────────┼────────────┼─────────────┼────────────┼───────┤
│       ▼             ▼            ▼             ▼            ▼       │
│                        DOMAIN LAYER                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │Use Cases │ │Entities  │ │Repository│ │ Failures │ │Interfaces│ │
│  │(Import,  │ │(Book,    │ │Contracts │ │(Server,  │ │          │ │
│  │ Export,  │ │ Chapter, │ │(abstract)│ │ Cache,   │ │          │ │
│  │ Delete)  │ │ Note...) │ │          │ │ File...) │ │          │ │
│  └────┬─────┘ └──────────┘ └────┬─────┘ └──────────┘ └──────────┘ │
│       │                         │                                  │
├───────┼─────────────────────────┼──────────────────────────────────┤
│       ▼                         ▼                                  │
│                         DATA LAYER                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │Repository│ │  Data    │ │   API    │ │  Local   │              │
│  │  Impls   │ │  Models  │ │DataSrc   │ │DataSrc   │              │
│  └────┬─────┘ └──────────┘ └────┬─────┘ └────┬─────┘              │
│       │                         │             │                    │
├───────┼─────────────────────────┼─────────────┼────────────────────┤
│       ▼                         ▼             ▼                    │
│                      EXTERNAL SERVICES                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ Gemini   │ │  Groq    │ │ OpenAI / │ │  SQLite  │              │
│  │   API    │ │   API    │ │  Claude  │ │  + Prefs │              │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Project Directory Structure

```
lib/
├── main.dart                          # App entry point, DI init, BlocProviders
├── app.dart                           # GoRouter configuration, MaterialApp.router
│
├── core/                              # Shared cross-cutting concerns
│   ├── constants/
│   │   └── app_constants.dart         # API keys, model names, URLs
│   ├── di/
│   │   ├── injection.dart             # GetIt + Injectable setup
│   │   ├── injection.config.dart      # Generated DI wiring (build_runner)
│   │   └── register_module.dart       # Third-party singletons (Dio, SharedPrefs, Gemini)
│   ├── error/
│   │   ├── exceptions.dart            # ServerException
│   │   └── failures.dart              # Failure hierarchy (Server, Cache, File, RateLimit...)
│   ├── services/
│   │   ├── audio_handler.dart         # EpubAudioHandler (media controls, TTS playback)
│   │   ├── background_service.dart    # Foreground service for bulk translation & PDF conversion
│   │   └── tts_service.dart           # Text-to-Speech with voice selection
│   ├── storage/
│   │   ├── database_helper.dart       # SQLite schema (books, translations, bookmarks, notes, progress)
│   │   └── in_memory_book_store.dart  # Volatile in-memory cache for parsed books
│   ├── theme/
│   │   ├── app_colors.dart            # Color palette constants
│   │   └── app_theme.dart             # ThemeData (dark theme, typography)
│   └── utils/
│       ├── app_logger.dart            # Centralized logging
│       ├── file_reader_native.dart    # Platform I/O (native)
│       ├── file_reader_web.dart       # Platform I/O (web)
│       ├── hash_utils.dart            # SHA-256 hashing for paragraph deduplication
│       ├── isolate_progress_helper.dart # Isolate-based progress callbacks
│       └── isolate_utils.dart         # Isolate helpers for heavy computation
│
├── features/                          # Feature-first modules (Clean Architecture)
│   ├── library/                       # Book management
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── local_book_datasource.dart    # SQLite CRUD for books
│   │   │   │   ├── epub_assembler.dart            # EPUB file assembly
│   │   │   │   └── pdf_converter_datasource.dart  # PDF-to-EPUB conversion
│   │   │   ├── models/
│   │   │   │   └── book_model.dart                # BookModel ↔ SQLite mapping
│   │   │   └── repositories/
│   │   │       └── library_repository_impl.dart   # LibraryRepository implementation
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── book.dart                      # Book entity (Equatable)
│   │   │   ├── repositories/
│   │   │   │   └── library_repository.dart        # Abstract contract
│   │   │   └── usecases/
│   │   │       ├── import_book.dart                # Import EPUB/PDF
│   │   │       ├── get_books.dart                  # Fetch all books
│   │   │       ├── delete_book.dart                # Delete book
│   │   │       ├── update_book.dart                # Update metadata
│   │   │       ├── export_service.dart             # Export translated book (EPUB/PDF/MD)
│   │   │       └── pdf_to_epub_usecase.dart        # PDF → EPUB conversion
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   ├── library_cubit.dart              # Library state management
│   │       │   └── library_state.dart              # States (Initial, Loading, Loaded, Error)
│   │       ├── pages/
│   │       │   ├── library_page.dart               # EPUB library grid
│   │       │   ├── pdf_library_page.dart           # PDF library
│   │       │   ├── pdf_conversion_page.dart        # PDF-to-EPUB converter UI
│   │       │   ├── exported_files_page.dart        # Generated files browser
│   │       │   ├── cover_search_page.dart          # Online cover search
│   │       │   └── main_shell.dart                 # Bottom navigation shell
│   │       └── widgets/
│   │           └── book_card.dart                  # Book card UI component
│   │
│   ├── reader/                        # EPUB/PDF reader
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── epub_parser_datasource.dart    # EPUB parsing (epubx, HTML extraction)
│   │   │   ├── models/
│   │   │   │   ├── bookmark_model.dart            # Bookmark ↔ SQLite
│   │   │   │   ├── note_model.dart                # Note ↔ SQLite
│   │   │   │   └── reading_progress_model.dart    # Progress ↔ SQLite
│   │   │   └── repositories/
│   │   │       └── reader_repository_impl.dart    # ReaderRepository implementation
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── reader_entities.dart            # Chapter, Paragraph (with image bytes)
│   │   │   │   ├── bookmark.dart                   # Bookmark entity
│   │   │   │   ├── note.dart                       # Note entity (highlight + annotation)
│   │   │   │   └── reading_progress.dart           # Progress tracking (chapter, paragraph, CFI)
│   │   │   ├── repositories/
│   │   │   │   └── reader_repository.dart          # Abstract contract
│   │   │   └── usecases/
│   │   │       ├── dictionary_service.dart         # Contextual word lookup
│   │   │       └── visual_content_service.dart     # Image extraction & rendering
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   ├── reader_cubit.dart               # Reader state management
│   │       │   └── reader_state.dart
│   │       ├── pages/
│   │       │   └── reader_page.dart                # Full reader UI
│   │       └── widgets/
│   │           ├── paragraph_tile.dart             # Paragraph rendering widget
│   │           ├── inline_translation_paragraph.dart # Bilingual paragraph
│   │           └── reader_drawer.dart              # Chapter navigation drawer
│   │
│   ├── translation/                   # AI translation engine
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── gemini_datasource.dart          # Google Gemini API
│   │   │   │   ├── groq_datasource.dart            # Groq API (LLaMA)
│   │   │   │   ├── openai_datasource.dart          # OpenAI GPT API
│   │   │   │   ├── claude_datasource.dart          # Anthropic Claude API
│   │   │   │   ├── translation_cache_datasource.dart # SQLite translation cache
│   │   │   │   └── usage_datasource.dart           # Rate limit / usage tracking
│   │   │   └── repositories/
│   │   │       └── translation_repository_impl.dart # Provider fallback chain
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── translation.dart                # Translation entity
│   │   │   └── repositories/
│   │   │       └── translation_repository.dart     # Abstract: translate(), translateBatch()
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   ├── translation_cubit.dart          # Single paragraph translation
│   │       │   ├── bulk_translation_cubit.dart     # Batch/background translation
│   │       │   └── translation_state.dart
│   │       └── widgets/
│   │           ├── translation_bubble.dart         # Inline translation popup
│   │           └── exhausted_bottom_sheet.dart     # Rate limit warning UI
│   │
│   ├── dictionary/                    # Contextual smart dictionary
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── dictionary_api_datasource.dart  # External dictionary API
│   │   │   └── repositories/
│   │   │       └── dictionary_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── dictionary_entry.dart           # Word definitions, phonetics
│   │   │   └── repositories/
│   │   │       └── dictionary_repository.dart
│   │   └── presentation/
│   │       ├── cubit/
│   │       │   ├── dictionary_cubit.dart
│   │       │   └── dictionary_state.dart
│   │       └── widgets/
│   │           └── dictionary_bottom_sheet.dart     # Lookup result bottom sheet
│   │
│   └── settings/                      # User preferences & API key management
│       ├── data/
│       │   ├── datasources/
│       │   │   └── settings_local_datasource.dart  # SharedPreferences persistence
│       │   └── repositories/
│       │       └── settings_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── user_settings.dart              # UserSettings (tier, keys, reader prefs)
│       │   └── repositories/
│       │       └── settings_repository.dart
│       └── presentation/
│           ├── cubit/
│           │   ├── settings_cubit.dart
│           │   └── settings_state.dart
│           └── pages/
│               └── settings_page.dart              # Settings configuration UI
│
├── models/                            # Legacy shared models
│   └── parsed_book.dart
├── screens/                           # Legacy screen layer (PDF reader)
│   ├── library/
│   │   └── library_screen.dart
│   └── reader/
│       └── reader_screen.dart
├── services/                          # Legacy service layer
│   ├── database/
│   │   └── database_service.dart
│   ├── import/
│   │   └── import_service.dart
│   ├── parsers/
│   │   └── pdf_parser.dart
│   ├── reader/
│   │   └── reader_notifier.dart
│   └── settings_service.dart
└── widgets/                           # Legacy widget layer
    └── reader/
        ├── chapter_drawer.dart
        ├── customization_panel.dart
        └── paragraph_item.dart
```

---

## 4. Architectural Layers

### 4.1 Presentation Layer

Manages the UI and user interaction. Each feature module has its own **Cubit** (lightweight BLoC) that emits state changes.

| Cubit | Responsibility |
|-------|---------------|
| `LibraryCubit` | Book CRUD, sorting, filtering, favorites, pinning |
| `ReaderCubit` | Chapter navigation, reading progress, bookmarks, notes |
| `TranslationCubit` | Single-paragraph AI translation |
| `BulkTranslationCubit` | Batch translation with progress tracking |
| `DictionaryCubit` | Contextual word lookup |
| `SettingsCubit` | User preferences, API key management, reader appearance |

**Global BLoC Provision:** All Cubits are registered as `lazySingleton` via `injectable` and provided globally through `MultiBlocProvider` in `main.dart`, ensuring a single shared instance across the widget tree.

### 4.2 Domain Layer

Contains pure business logic with **zero dependencies** on Flutter or external packages.

- **Entities:** Immutable value objects using `Equatable` (`Book`, `Chapter`, `Paragraph`, `Translation`, `Bookmark`, `Note`, `ReadingProgress`, `UserSettings`, `DictionaryEntry`)
- **Repository Contracts:** Abstract classes defining data access interfaces
- **Use Cases:** Single-responsibility operations (`ImportBook`, `GetBooks`, `DeleteBook`, `UpdateBook`, `ExportService`, `PdfToEpubUseCase`, `DictionaryService`, `VisualContentService`)
- **Failure Types:** Typed error handling via `dartz.Either<Failure, T>` — `ServerFailure`, `CacheFailure`, `FileFailure`, `RateLimitFailure`, `AllProvidersExhaustedFailure`

### 4.3 Data Layer

Implements domain contracts and handles all I/O.

- **Repository Implementations:** Orchestrate data sources, map models to entities
- **Data Models:** SQLite-compatible objects with `toMap()` / `fromMap()` serialization
- **Data Sources:**
  - **Local:** `DatabaseHelper` (SQLite via `sqflite`), `SharedPreferences`
  - **Remote:** REST API clients for Gemini, Groq, OpenAI, Claude (via `Dio`)
  - **Cache:** Translation cache datasource for hash-based deduplication

---

## 5. Communication & Data Flow

### 5.1 Translation Pipeline

```
User taps paragraph → TranslationCubit.translate()
         │
         ▼
  TranslationRepository.translate()
         │
         ├──→ Check translation cache (SQLite lookup by paragraph_hash + language_pair)
         │         │
         │         ├── Cache HIT → Return cached Translation
         │         │
         │         └── Cache MISS ──→ Provider fallback chain:
         │                                │
         │                           ┌────┴────────────────────────────┐
         │                           │  Tier-based provider selection  │
         │                           │                                 │
         │                           │  Starter: Google Translate      │
         │                           │  Pro:     Gemini ↔ Groq         │
         │                           │  Elite:   GPT-4o / Claude       │
         │                           └────┬────────────────────────────┘
         │                                │
         │                           ┌────▼────┐
         │                           │ AI API  │  (REST via Dio)
         │                           │ Request │  System prompt: literary translator
         │                           └────┬────┘  Response: JSON {original, translation}
         │                                │
         │                           Save to cache (SQLite)
         │                                │
         └───────────────────────────────►│
                                          ▼
                            TranslationState.loaded → UI Update
```

### 5.2 Background Translation & Export

```
User triggers bulk export
         │
         ▼
  FlutterBackgroundService.invoke('startExport', {...})
         │
         ▼
  ┌──────────────────────────────────────────┐
  │       FOREGROUND SERVICE (Android)       │
  │                                          │
  │  Phase 1: Extract paragraphs from EPUB   │
  │           ↓                              │
  │  Phase 2: Batch translate (10/batch)     │
  │           → Notification progress bar    │
  │           ↓                              │
  │  Phase 3: Generate output file           │
  │           (EPUB / PDF / Markdown)        │
  │           ↓                              │
  │  Phase 4: Save to library + notify       │
  │           service.invoke('onComplete')   │
  └──────────────────────────────────────────┘
         │
         ▼
  LibraryCubit.loadBooks()  (UI refresh)
```

### 5.3 Reader Data Flow

```
User opens book → ReaderCubit.openBook(Book)
         │
         ├──→ EpubParserDatasource.parseEpub(filePath)
         │         │
         │         ├── Parse EPUB (epubx library)
         │         ├── Extract HTML content per chapter
         │         ├── Strip tags → Paragraph list
         │         └── Hash each paragraph (SHA-256)
         │
         ├──→ ReaderRepository.getReadingProgress(bookId)
         │         └── Restore last position (chapter, paragraph, CFI)
         │
         └──→ Emit ReaderState.loaded(chapters, currentChapter, progress)
                    │
                    ├── User taps paragraph → TranslationCubit
                    ├── User long-presses word → DictionaryCubit
                    ├── User taps play → EpubAudioHandler (TTS)
                    └── User scrolls → Save progress to SQLite
```

### 5.4 TTS (Text-to-Speech) Audio Pipeline

```
EpubAudioHandler (extends BaseAudioHandler)
         │
         ├── Receives media controls (Play, Pause, Skip, Stop)
         │   from system notification / lock screen
         │
         ├── Delegates to TtsService.speak(text, voice)
         │         │
         │         ├── AudioSession configuration
         │         ├── flutter_tts engine
         │         └── Voice selection from SettingsCubit
         │
         └── Auto-advances: onComplete → _playNext()
             Broadcasts PlaybackState to system media controls
```

### 5.5 Navigation Flow

```
                    ┌──────────────────────────┐
                    │       GoRouter            │
                    │     (app.dart)            │
                    └───────────┬──────────────┘
                                │
                    ┌───────────┴──────────────┐
                    │       ShellRoute          │
                    │    (MainShell + BottomNav) │
                    ├───────────────────────────┤
                    │ /          → LibraryPage  │
                    │ /pdf-library → PDFs       │
                    │ /pdf-convert → Converter  │
                    │ /exported-files → Files   │
                    │ /settings  → SettingsPage │
                    └───────────────────────────┘
                                │
                    ┌───────────┴──────────────┐
                    │   Standalone Routes       │
                    │   (no bottom nav)         │
                    ├───────────────────────────┤
                    │ /reader    → ReaderPage   │  (extra: Book)
                    │ /pdf-reader → ReaderScreen│  (extra: Book)
                    └───────────────────────────┘
```

---

## 6. Dependency Injection

The project uses **GetIt** + **Injectable** for compile-time-safe DI with code generation.

```
main() → configureDependencies() → getIt.init()
         │
         ├── @module RegisterModule
         │       ├── SharedPreferences (preResolve)
         │       ├── Dio (lazySingleton)
         │       └── GenerativeModel (lazySingleton, @Named)
         │
         ├── @lazySingleton — All Cubits, Repositories, DataSources, Services
         │
         └── MultiBlocProvider wraps app with globally shared Cubit instances
```

**Registration Scopes:**
| Scope | Usage |
|-------|-------|
| `@preResolve` | `SharedPreferences` (async initialization) |
| `@lazySingleton` | All Cubits, Repositories, DataSources, `DatabaseHelper`, `TtsService`, `EpubAudioHandler` |
| `@module` | Third-party types not owned by the project (Dio, Gemini, SharedPreferences) |

---

## 7. Database Schema

The app uses **SQLite** (via `sqflite`) with 5 core tables:

```sql
┌──────────────────────────────────────────────────────┐
│                      books                           │
├──────────────────────────────────────────────────────┤
│ id TEXT PRIMARY KEY                                  │
│ title TEXT NOT NULL                                  │
│ author TEXT                                          │
│ file_path TEXT NOT NULL                              │
│ cover_image BLOB                                    │
│ cover_url TEXT                                       │
│ status TEXT DEFAULT 'reading'                        │
│ is_favorite INTEGER DEFAULT 0                        │
│ is_pinned INTEGER DEFAULT 0                          │
│ reading_progress REAL DEFAULT 0                      │
│ format TEXT DEFAULT 'epub'                            │
│ added_at INTEGER NOT NULL                            │
│ last_read_at INTEGER                                 │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                   translations                       │
├──────────────────────────────────────────────────────┤
│ id INTEGER PRIMARY KEY AUTOINCREMENT                 │
│ book_id TEXT NOT NULL                                │
│ paragraph_hash TEXT NOT NULL                         │
│ original_text TEXT NOT NULL                          │
│ translated_text TEXT NOT NULL                        │
│ language_pair TEXT NOT NULL                           │
│ provider TEXT                                        │
│ created_at INTEGER NOT NULL                          │
│ UNIQUE(book_id, paragraph_hash, language_pair)       │
│ INDEX idx_cache_lookup (book_id, paragraph_hash,     │
│                         language_pair)                │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                    bookmarks                         │
├──────────────────────────────────────────────────────┤
│ id INTEGER PRIMARY KEY AUTOINCREMENT                 │
│ book_id TEXT NOT NULL                                │
│ chapter_index INTEGER NOT NULL                       │
│ paragraph_index INTEGER NOT NULL                     │
│ title TEXT                                           │
│ created_at INTEGER NOT NULL                          │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                      notes                           │
├──────────────────────────────────────────────────────┤
│ id INTEGER PRIMARY KEY AUTOINCREMENT                 │
│ book_id TEXT NOT NULL                                │
│ chapter_index INTEGER NOT NULL                       │
│ paragraph_index INTEGER NOT NULL DEFAULT 0           │
│ paragraph_hash TEXT NOT NULL                         │
│ selected_text TEXT NOT NULL DEFAULT ''                │
│ note_text TEXT                                       │
│ color_mark TEXT                                      │
│ created_at INTEGER NOT NULL                          │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                 reading_progress                     │
├──────────────────────────────────────────────────────┤
│ id INTEGER PRIMARY KEY AUTOINCREMENT                 │
│ book_id TEXT NOT NULL → FK books(id)                 │
│ chapter_index INTEGER NOT NULL                       │
│ paragraph_index INTEGER NOT NULL DEFAULT 0           │
│ scroll_position REAL                                 │
│ progress_percent REAL DEFAULT 0                      │
│ format TEXT DEFAULT 'epub'                           │
│ epub_cfi TEXT                                        │
│ updated_at INTEGER NOT NULL                          │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                 vocabulary_vault                     │
├──────────────────────────────────────────────────────┤
│ id INTEGER PRIMARY KEY AUTOINCREMENT                 │
│ word TEXT NOT NULL                                   │
│ context_paragraph TEXT NOT NULL                      │
│ meaning TEXT NOT NULL                                │
│ language TEXT NOT NULL                                │
│ added_at INTEGER NOT NULL                            │
│ last_reviewed_at INTEGER                             │
└──────────────────────────────────────────────────────┘
```

---

## 8. AI Translation Providers

The app supports a tiered provider system with automatic fallback:

| Tier | Providers | Model | Access |
|------|-----------|-------|--------|
| **Starter** | Google Translate | — | Free, via `translator` package |
| **Pro** | Gemini, Groq | `gemini-1.5-flash`, LLaMA (via Groq) | API key required |
| **Elite** | OpenAI, Claude | GPT-4o, Claude | API key required |

**Translation Strategy:**
- Each provider receives a **literary translation system prompt** that enforces natural language flow over literal translation
- Responses are returned as structured JSON `{"original": "...", "translation": "..."}`
- All translations are **hash-cached** in SQLite using `SHA-256(paragraph_text)` + `language_pair` as the cache key
- On provider failure, the system automatically falls back to the next available provider

---

## 9. Technology Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.x (Dart SDK ^3.10.4) |
| **State Management** | `flutter_bloc` / Cubit |
| **Dependency Injection** | `get_it` + `injectable` (with `build_runner`) |
| **Navigation** | `go_router` (declarative, URL-based) |
| **HTTP Client** | `dio` |
| **AI/ML** | `google_generative_ai`, REST APIs (Groq, OpenAI, Claude) |
| **EPUB Parsing** | `epubx`, `html` |
| **PDF** | `pdfx`, `pdfrx`, `syncfusion_flutter_pdf`, `pdf` |
| **OCR** | `google_mlkit_text_recognition`, `flutter_tesseract_ocr` |
| **Database** | `sqflite` (SQLite) |
| **Key-Value Store** | `shared_preferences`, `flutter_secure_storage` |
| **TTS** | `flutter_tts`, `audio_service`, `audio_session` |
| **Background Tasks** | `flutter_background_service`, `workmanager` |
| **Notifications** | `flutter_local_notifications` |
| **UI** | `google_fonts`, `shimmer`, `lottie`, `cached_network_image`, `flutter_markdown` |
| **Utilities** | `dartz` (functional), `equatable`, `crypto`, `uuid`, `intl`, `archive` |

---

## 10. Error Handling Strategy

The project uses **functional error handling** with `dartz.Either<Failure, T>`:

```dart
// Domain layer returns typed failures instead of throwing exceptions
Future<Either<Failure, Translation>> translate(...);

// Presentation layer pattern-matches on the result
result.fold(
  (failure) => emit(TranslationError(failure.message)),
  (translation) => emit(TranslationLoaded(translation)),
);
```

**Failure Hierarchy:**
- `ServerFailure` — API errors (network, auth, rate limit)
- `CacheFailure` — SQLite read/write errors
- `FileFailure` — File system I/O errors
- `RateLimitFailure` — Provider quota exceeded
- `AllProvidersExhaustedFailure` — All AI providers failed

---

## 11. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Feature-first modular structure** | Each feature is self-contained with its own data/domain/presentation layers, enabling independent development and testing |
| **Cubit over full BLoC** | Simpler API for straightforward state transitions without complex event mapping |
| **Hash-based translation cache** | SHA-256 paragraph hashes enable cache hits across books sharing identical paragraphs |
| **Foreground service for bulk operations** | Android requires foreground services for long-running tasks; progress is shown via system notifications |
| **Provider fallback chain** | Resilience against individual API failures or rate limits |
| **`dartz.Either` for error handling** | Compile-time enforced error handling without try/catch proliferation |
| **Lazy singletons** | Memory-efficient initialization; services created only when first accessed |
| **GoRouter with ShellRoute** | Persistent bottom navigation across library tabs while reader pages operate independently |

---

## 12. Build & Run

```bash
# Install dependencies
flutter pub get

# Generate DI code (required after modifying @injectable annotations)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Build for release (Android)
flutter build apk --release
```

**Environment Setup:** Create a `.env` file in the project root:
```env
GEMINI_API_KEY=your_gemini_key
GROQ_API_KEY=your_groq_key
```

---

*This document is auto-generated from the source code structure and should be updated when significant architectural changes are made.*


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
