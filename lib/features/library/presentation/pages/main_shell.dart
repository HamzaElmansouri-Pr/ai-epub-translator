import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location == '/pdf-library') return 1;
    if (location == '/pdf-convert') return 2;
    if (location == '/exported-files') return 3;
    if (location == '/settings') return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/pdf-library');
        break;
      case 2:
        context.go('/pdf-convert');
        break;
      case 3:
        context.go('/exported-files');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined),
              activeIcon: Icon(Icons.library_books_rounded),
              label: 'ePubs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.picture_as_pdf_outlined),
              activeIcon: Icon(Icons.picture_as_pdf_rounded),
              label: 'PDFs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Convert',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder_rounded),
              label: 'Files',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
