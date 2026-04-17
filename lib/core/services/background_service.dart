import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/features/translation/domain/repositories/translation_repository.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/data/models/book_model.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Translation Service',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  AppConstants.defaultGeminiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
  AppConstants.defaultGroqKey = dotenv.get('GROQ_API_KEY', fallback: '');

  await configureDependencies();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('startExport').listen((event) async {
    if (event == null) return;

    final bookId = event['bookId'] as String;
    final bookTitle = event['bookTitle'] as String;
    final filePath = event['originalFilePath'] as String;
    final targetLang = event['targetLanguage'] as String;
    final isPdf = event['isPdf'] as bool;
    final isMd = event['isMd'] as bool? ?? false;
    final useGoogle = event['useGoogle'] as bool;

    final exportService = getIt<ExportService>();
    final translationRepo = getIt<TranslationRepository>();
    final localDataSource = getIt<LocalBookDataSource>();

    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Extracting $bookTitle',
        'Gathering text paragraphs...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );
    }

    final paragraphs = await exportService.extractAllParagraphs(filePath);
    final validParagraphs = paragraphs
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    int processedCount = 0;
    const batchSize = 10;

    for (int i = 0; i < validParagraphs.length; i += batchSize) {
      final chunk = validParagraphs.skip(i).take(batchSize).toList();

      await translationRepo.translateBatch(
        chunk,
        targetLanguage: targetLang,
        bookId: bookId,
        useGoogleTranslate: useGoogle,
      );

      processedCount += chunk.length;
      final percent = ((processedCount / validParagraphs.length) * 100).toInt();

      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Translating $bookTitle',
          'Progress: $percent% ($processedCount/${validParagraphs.length})',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
              showProgress: true,
              maxProgress: 100,
              progress: percent,
            ),
          ),
        );
      }
    }

    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Packaging $bookTitle',
        'Generating final file...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );
    }

    final generatedFile = isPdf
        ? await exportService.generateBilingualPdf(bookId, bookTitle, filePath)
        : isMd
            ? await exportService.generateBilingualMarkdown(bookId, bookTitle, filePath)
            : await exportService.generateBilingualEpub(bookId, bookTitle, filePath);

    final newBook = BookModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$bookTitle (Translated)',
      author: 'Epub Translate App',
      filePath: generatedFile.path,
      addedAt: DateTime.now(),
    );

    await localDataSource.saveBook(newBook);

    service.invoke('onComplete', {'filePath': generatedFile.path});

    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Translation Complete!',
        bookTitle + ' has been added to your library.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: false,
          ),
        ),
      );
      service.setAsBackgroundService();
      service.stopSelf();
    }
  });
}
