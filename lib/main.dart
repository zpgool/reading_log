import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'screens/library_screen.dart';
import 'screens/timer_screen.dart';

void main() {
  runApp(const ReadingApp());
}

class ReadingApp extends StatelessWidget {
  const ReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '독서 기록',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

/// 하단 탭 3개: 내 서재 / 독서 타이머 / 독서 캘린더
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _screens = [
    LibraryScreen(),
    TimerScreen(),
    CalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '내 서재'),
          NavigationDestination(icon: Icon(Icons.timer), label: '독서 타이머'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '독서 캘린더'),
        ],
      ),
    );
  }
}
