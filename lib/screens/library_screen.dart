import 'package:flutter/material.dart';

/// 내 서재: 등록한 책과 누적 독서 시간, 책 등록
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 서재')),
      body: const Center(child: Text('내 서재')),
    );
  }
}
