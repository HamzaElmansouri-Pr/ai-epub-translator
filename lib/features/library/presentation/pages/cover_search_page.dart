import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';

class CoverSearchPage extends StatefulWidget {
  final Book book;

  const CoverSearchPage({super.key, required this.book});

  @override
  State<CoverSearchPage> createState() => _CoverSearchPageState();
}

class _CoverSearchPageState extends State<CoverSearchPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final searchQuery = widget.book.title;
    final initialUrl = 'https://www.google.com/search?tbm=isch&q=\${Uri.encodeComponent(searchQuery + " epub book cover")}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'CoverSelector',
        onMessageReceived: (JavaScriptMessage message) {
          _onImageSelected(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectImageSelectionScript();
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  void _injectImageSelectionScript() {
    // This script attaches a long-press listener to all images on the page.
    final script = '''
      longPressTimeout = null;
      document.body.addEventListener('touchstart', function(e) {
        if (e.target.tagName === 'IMG') {
          longPressTimeout = setTimeout(function() {
            var url = e.target.src || e.target.getAttribute('data-src');
            if (url) {
              CoverSelector.postMessage(url);
            }
          }, 1500); // 1.5 seconds for long press
        }
      });
      document.body.addEventListener('touchend', function(e) {
        clearTimeout(longPressTimeout);
      });
      document.body.addEventListener('touchmove', function(e) {
        clearTimeout(longPressTimeout);
      });
    ''';
    _controller.runJavaScript(script);
  }

  void _onImageSelected(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      // Don't support base64 images to keep DB size small, only real URLs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an actual image link, not a base64 encoded image.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Import Cover?', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl, height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.white)),
              const SizedBox(height: 16),
              const Text('Do you want to use this image as the book cover?', style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _importCover(imageUrl);
              },
              child: const Text('Import', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  void _importCover(String imageUrl) {
    if (context.mounted) {
      // Save it using cubit
      context.read<LibraryCubit>().updateBookCover(widget.book, imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover imported successfully!')),
      );
      Navigator.pop(context); // Go back to library
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Search Cover: \${widget.book.title}', style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            color: Colors.blueAccent.withValues(alpha: 0.2),
            width: double.infinity,
            child: const Text(
              'Long press (2 seconds) on any image to import it as the cover.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
