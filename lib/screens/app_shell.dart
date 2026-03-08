import 'package:flutter/material.dart';
import 'workspace_screen.dart';
import 'workspaces_screen.dart';
import 'templates_screen.dart';
import 'memory_dashboard_screen.dart';
import 'ai_settings_screen.dart';

class AppShell extends StatefulWidget {
  static final GlobalKey<AppShellState> stateKey = GlobalKey<AppShellState>();
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void setIndex(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    WorkspaceScreen(),
    WorkspacesScreen(),
    TemplatesScreen(),
    MemoryDashboardScreen(),
    AISettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppShell.stateKey,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspaces_outlined),
              activeIcon: Icon(Icons.workspaces),
              label: 'Workspaces',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Templates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'Memory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
