import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_translate_meaning/services/reader/reader_notifier.dart';

class ReaderSettings {
  final double fontSize;
  final String fontFamily;
  final double lineSpacing;
  final ReaderTheme theme;
  final String textAlign; // 'left' or 'justify'

  ReaderSettings({
    required this.fontSize,
    required this.fontFamily,
    required this.lineSpacing,
    required this.theme,
    required this.textAlign,
  });
}

class SettingsService {
  static const String _keyFontSize = 'reader_font_size';
  static const String _keyFontFamily = 'reader_font_family';
  static const String _keyLineSpacing = 'reader_line_spacing';
  static const String _keyTheme = 'reader_theme';
  static const String _keyTextAlign = 'reader_text_align';

  Future<void> saveReaderSettings(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, settings.fontSize);
    await prefs.setString(_keyFontFamily, settings.fontFamily);
    await prefs.setDouble(_keyLineSpacing, settings.lineSpacing);
    await prefs.setInt(_keyTheme, settings.theme.index);
    await prefs.setString(_keyTextAlign, settings.textAlign);
  }

  Future<ReaderSettings> loadReaderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderSettings(
      fontSize: prefs.getDouble(_keyFontSize) ?? 17.0,
      fontFamily: prefs.getString(_keyFontFamily) ?? 'Serif',
      lineSpacing: prefs.getDouble(_keyLineSpacing) ?? 1.6,
      theme: ReaderTheme.values[prefs.getInt(_keyTheme) ?? 0],
      textAlign: prefs.getString(_keyTextAlign) ?? 'left',
    );
  }
}
