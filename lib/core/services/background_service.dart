import 'dart:async';
import 'dart:io';
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
import 'package:epub_translate_meaning/features/library/domain/usecases/pdf_to_epub_usecase.dart';

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
    final isBilingual = event['isBilingual'] as bool? ?? true;
    final skipTranslation = event['skipTranslation'] as bool? ?? false;

    final exportService = getIt<ExportService>();
    final translationRepo = getIt<TranslationRepository>();
    final localDataSource = getIt<LocalBookDataSource>();

    if (!skipTranslation) {
      // Phase 1: Extraction
      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Extracting $bookTitle',
          'Gathering text paragraphs...',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: '@mipmap/ic_launcher',
              ongoing: true,
              showProgress: true,
              maxProgress: 100,
              progress: 0,
              indeterminate: true,
            ),
          ),
        );
      }

      final paragraphs = await exportService.extractAllParagraphs(filePath);
      final validParagraphs = paragraphs
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length > 5)
          .toList();

      // Phase 2: Translation
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
    }

    // Phase 3: Packaging
    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Packaging $bookTitle',
        'Generating final ${isPdf ? "PDF" : (isMd ? "Markdown" : "EPUB")} file...',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: '@mipmap/ic_launcher',
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: 95,
          ),
        ),
      );
    }

    final generatedFile = isPdf
        ? await exportService.generatePdf(bookId, bookTitle, filePath, targetLanguage: targetLang, isBilingual: isBilingual)
        : isMd
            ? await exportService.generateMarkdown(bookId, bookTitle, filePath, targetLanguage: targetLang, isBilingual: isBilingual)
            : await exportService.generateEpub(bookId, bookTitle, filePath, targetLanguage: targetLang, isBilingual: isBilingual);

    final newBook = BookModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$bookTitle (${isBilingual ? "Bilingual" : "Translated"})',
      author: 'Epub Translate App',
      filePath: generatedFile.path,
      addedAt: DateTime.now(),
    );

    await localDataSource.saveBook(newBook);

    service.invoke('onComplete', {'filePath': generatedFile.path});

    // Phase 4: Complete
    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Translation Complete!',
        '$bookTitle has been added to your library.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: '@mipmap/ic_launcher',
            ongoing: false,
          ),
        ),
      );
      service.setAsBackgroundService();
      // Keep service alive for a few seconds to ensure notification shows
      Timer(const Duration(seconds: 5), () {
        service.stopSelf();
      });
    }
  });

  service.on('startPdfToEpub').listen((event) async {
    if (event == null) return;

    final pdfPath = event['pdfPath'] as String;
    final title = event['title'] as String;
    final author = event['author'] as String;
    final endPage = event['endPage'] as int?;

    final pdfToEpubUseCase = getIt<PdfToEpubUseCase>();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      flutterLocalNotificationsPlugin.show(
        889,
        'Starting PDF Conversion',
        'Preparing $title...',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: '@mipmap/ic_launcher',
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: 0,
          ),
        ),
      );
    }

    final pdfFile = File(pdfPath);
    if (!await pdfFile.exists()) {
      debugPrint('Background Service ERROR: PDF file not found at $pdfPath');
      service.invoke('onProgress', {'progress': 0, 'status': 'Error: PDF file not found'});
      return;
    }
    final size = await pdfFile.length();
    debugPrint('Background Service: Starting conversion for $title ($size bytes)');

    try {
      final outFile = await pdfToEpubUseCase.execute(
        pdfPath: pdfPath,
        title: title,
        author: author,
        endPage: endPage,
        onProgress: (progress, status) {
          final percent = (progress * 100).toInt();
          service.invoke('onProgress', {
            'progress': progress,
            'status': status,
          });
          if (service is AndroidServiceInstance) {
            flutterLocalNotificationsPlugin.show(
              889,
              'Converting: $title',
              '$status ($percent%)',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'my_foreground',
                  'MY FOREGROUND SERVICE',
                  icon: '@mipmap/ic_launcher',
                  ongoing: true,
                  showProgress: true,
                  maxProgress: 100,
                  progress: percent,
                ),
              ),
            );
          }
        },
      );

      service.invoke('onComplete', {'filePath': outFile.path});
      
      // Safety delay for I/O completion
      await Future.delayed(const Duration(seconds: 1));

      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          889,
          'Conversion Complete!',
          '$title has been saved to your library and downloads.',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: '@mipmap/ic_launcher',
              ongoing: false,
            ),
          ),
        );
        service.setAsBackgroundService();
        Timer(const Duration(seconds: 5), () {
          service.stopSelf();
        });
      }
    } catch (e) {
      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          889,
          'Conversion Failed',
          'An error occurred while converting $title.',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: '@mipmap/ic_launcher',
              ongoing: false,
            ),
          ),
        );
        service.setAsBackgroundService();
      }
    }
  });
}
