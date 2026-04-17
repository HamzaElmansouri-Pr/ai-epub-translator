class AppConstants {
  static const String appName = 'EPub Translate Meaning';

  // Translation Tiers
  static const int starterDailyLimit = 50;

  // API Endpoints
  static const String geminiModel = 'gemini-1.5-flash';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqModel = 'llama-3.3-70b-versatile';

  // API Keys (Loaded from .env in main.dart)
  static String defaultGeminiKey = '';
  static String defaultGroqKey = '';
}
