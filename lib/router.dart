import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/calendar_screen.dart';
import 'screens/library_screen.dart';
import 'screens/timer_screen.dart';

/// 탭 순서와 주소
const _tabs = ['/library', '/timer', '/calendar'];

final router = GoRouter(
  initialLocation: '/library',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/library', builder: (context, state) => const LibraryScreen()),
        GoRoute(
          path: '/timer',
          // 내 서재에서 책을 누르면 /timer?bookId=1 로 들어온다
          builder: (context, state) => TimerScreen(
            bookId: int.tryParse(state.uri.queryParameters['bookId'] ?? ''),
          ),
        ),
        GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
      ],
    ),
  ],
);

/// 하단 탭 3개: 내 서재 / 독서 타이머 / 독서 캘린더
class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = _tabs.indexOf(path);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '내 서재'),
          NavigationDestination(icon: Icon(Icons.timer), label: '독서 타이머'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '독서 캘린더'),
        ],
      ),
    );
  }
}
