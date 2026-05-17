import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/pdf_to_epub_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:pdfx/pdfx.dart';

class PdfConversionPage extends StatefulWidget {
  const PdfConversionPage({super.key});

  @override
  State<PdfConversionPage> createState() => _PdfConversionPageState();
}

class _PdfConversionPageState extends State<PdfConversionPage> {
  bool _isProcessing = false;
  double _progress = 0;
  String _status = 'Select a PDF to start';
  String? _selectedPath;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  StreamSubscription? _serviceSubscription;
  int _totalPages = 0;
  int _selectedPages = 0;

  Future<void> _pickFile() async {
    setState(() {
      _isProcessing = true;
      _status = 'Verifying API...';
    });

    try {
      final useCase = getIt<PdfToEpubUseCase>();
      final isApiWorking = await useCase.checkApiStatus();
      
      setState(() => _isProcessing = false);

      if (!isApiWorking) {
        _showApiKeyGuide();
        return;
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = 'Select a PDF to start';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API Error: $e'), backgroundColor: Colors.red),
      );
      _showApiKeyGuide();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      int pages = 0;
      try {
        final document = await PdfDocument.openFile(path);
        pages = document.pagesCount;
        await document.close();
      } catch (e) {
        debugPrint('Error reading PDF pages: $e');
      }

      if (!mounted) return;

      setState(() {
        _selectedPath = path;
        _titleController.text = result.files.single.name.replaceAll('.pdf', '');
        _authorController.text = 'AI Converted';
        _totalPages = pages;
        _selectedPages = pages;
      });
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startConversion() async {
    if (_selectedPath == null) return;

    // Check permissions before starting
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // On Android 11+ (SDK 30+), we might need Manage External Storage for PDFs
      if (!status.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage access is required. Please enable it in settings.'),
                backgroundColor: Colors.redAccent,
                action: SnackBarAction(
                  label: 'SETTINGS',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }
    }

    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) await service.startService();

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = 'Starting background service...';
    });

    service.invoke('startPdfToEpub', {
      'pdfPath': _selectedPath,
      'title': _titleController.text,
      'author': _authorController.text,
      'endPage': _selectedPages > 0 ? _selectedPages : null,
    });

    _serviceSubscription = service.on('onProgress').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _progress = (event['progress'] as num).toDouble();
          _status = event['status'] as String;
        });
      }
    });

    service.on('onComplete').listen((event) {
      if (mounted) {
        context.read<LibraryCubit>().loadBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversion Complete!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    });
  }

  void _showApiKeyGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gemini API Key Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Elite conversion requires an active Gemini API key. Follow these steps to get one for free:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildStep(
                '1',
                'Go to Google AI Studio',
                'Visit aistudio.google.com to access the Gemini API platform.',
              ),
              _buildStep(
                '2',
                'Create API Key',
                'Click "Get API Key" and create a new key for your project.',
              ),
              _buildStep(
                '3',
                'Copy and Save',
                'Copy the key and paste it into the app settings.',
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Assuming there's a route for settings or a way to enter key
                  // We'll just point them to settings
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Elite Converter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              centerTitle: true,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!_isProcessing) ...[
                  Text(
                    'PDF Workshop',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transform your old PDFs into professional EPUBs with AI Vision.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  
                  // Selection Card
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPath == null ? AppColors.border : AppColors.primary.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedPath == null
                                ? Icons.auto_stories_outlined
                                : Icons.check_circle_rounded,
                            size: 48,
                            color: _selectedPath == null
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedPath == null
                                ? 'Choose a PDF Book'
                                : 'Source Ready',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                          ),
                          if (_selectedPath != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _selectedPath!.split(Platform.pathSeparator).last,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (_totalPages > 0) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Page Range Selection',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Convert through page:', style: Theme.of(context).textTheme.bodyMedium),
                              Text('$_selectedPages / $_totalPages', 
                                style: Theme.of(context).textTheme.labelLarge),
                            ],
                          ),
                          Slider(
                            value: _selectedPages.toDouble(),
                            min: 1,
                            max: _totalPages.toDouble(),
                            onChanged: (value) => setState(() => _selectedPages = value.toInt()),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text(
                    'Metadata Details',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _selectedPath != null ? _startConversion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'START CONVERSION',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 12,
                                backgroundColor: AppColors.surface,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _status,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Your book is being crafted by AI.\nYou can leave this page safely.',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
