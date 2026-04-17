import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';

abstract class UsageDataSource {
  Future<bool> canTranslate();
  Future<void> incrementUsage();
  Future<int> getRemainingTokens();
}

@LazySingleton(as: UsageDataSource)
class UsageDataSourceImpl implements UsageDataSource {
  final SharedPreferences prefs;
  static const String _countKey = 'daily_translation_count';
  static const String _dateKey = 'last_translation_date';

  UsageDataSourceImpl(this.prefs);

  @override
  Future<bool> canTranslate() async {
    await _checkAndResetDaily();
    final currentCount = prefs.getInt(_countKey) ?? 0;
    return currentCount < AppConstants.starterDailyLimit;
  }

  @override
  Future<void> incrementUsage() async {
    final currentCount = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_countKey, currentCount + 1);
    await prefs.setString(_dateKey, _today());
  }

  @override
  Future<int> getRemainingTokens() async {
    await _checkAndResetDaily();
    final currentCount = prefs.getInt(_countKey) ?? 0;
    return AppConstants.starterDailyLimit - currentCount;
  }

  Future<void> _checkAndResetDaily() async {
    final lastDate = prefs.getString(_dateKey);
    final today = _today();

    if (lastDate != today) {
      await prefs.setInt(_countKey, 0);
      await prefs.setString(_dateKey, today);
    }
  }

  String _today() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }
}
