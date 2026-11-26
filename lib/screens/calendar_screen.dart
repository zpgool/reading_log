import 'package:flutter/material.dart';

/// 독서 캘린더: 월별 캘린더, 날짜별 읽은 책과 독서 시간
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('독서 캘린더')),
      body: const Center(child: Text('독서 캘린더')),
    );
  }
}
