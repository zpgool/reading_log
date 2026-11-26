import 'package:flutter/material.dart';

/// 독서 타이머: 책 선택 후 시작·일시정지·종료
class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('독서 타이머')),
      body: const Center(child: Text('독서 타이머')),
    );
  }
}
