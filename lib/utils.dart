import 'package:flutter/material.dart';

/// 앱 색상
const paperColor = Color(0xFFFAF7F2); // 배경
const inkColor = Color(0xFF2F5D50); // 메인
const amberColor = Color(0xFFE0A458); // 강조 (측정 중, 읽은 날)

/// 초 → "1시간 5분", "45분", "1분 미만"
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
  if (m > 0) return '$m분';
  return seconds > 0 ? '1분 미만' : '0분';
}

/// 2차 확인 창. 확인 버튼을 누르면 true
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String cancelText = '취소',
  bool danger = false, // 삭제처럼 되돌릴 수 없는 작업이면 빨간 버튼
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red[700]) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok ?? false; // 바깥을 눌러 닫으면 취소
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 초 → 타이머 표시 "00:23:41"
String formatTimer(int seconds) =>
    '${_two(seconds ~/ 3600)}:${_two(seconds % 3600 ~/ 60)}:${_two(seconds % 60)}';

/// 시각 → "20:05" (기기 시간대)
String formatClock(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}
