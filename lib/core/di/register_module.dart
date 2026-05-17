import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';

@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @lazySingleton
  Dio get dio => Dio();

  @Named('geminiModel')
  @lazySingleton
  GenerativeModel get geminiModel => GenerativeModel(
        model: AppConstants.geminiModel,
        apiKey: AppConstants.defaultGeminiKey,
      );
}
