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
