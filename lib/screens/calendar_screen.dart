import 'package:flutter/material.dart';

import '../repositories/reading_log_repository.dart';
import '../utils.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 읽은 시간에 따른 칸 진하기 3단계
const _levels = [
  (label: '30분 미만', alpha: 0.35),
  (label: '1시간 미만', alpha: 0.65),
  (label: '1시간 이상', alpha: 1.0),
];

double _levelAlpha(int seconds) =>
    _levels[seconds < 1800 ? 0 : (seconds < 3600 ? 1 : 2)].alpha;

int _sum(List<DayBookTime>? items) => items?.fold<int>(0, (s, e) => s + e.seconds) ?? 0;

/// 독서 캘린더: 월별 캘린더, 날짜별 읽은 책과 독서 시간
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = ReadingLogRepository();
  final _now = DateTime.now();

  late DateTime _month = DateTime(_now.year, _now.month); // 보고 있는 달의 1일
  late int? _selectedDay = _now.day;
  Map<int, List<DayBookTime>>? _byDay; // 날짜 → 그날 읽은 책들. null이면 불러오는 중
  Object? _error;

  bool get _isThisMonth => _month.year == _now.year && _month.month == _now.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    try {
      final rows = await _repo.findMonth(month.year, month.month);
      if (!mounted || month != _month) return; // 그사이 다른 달로 넘겼으면 버림

      final byDay = <int, List<DayBookTime>>{};
      for (final r in rows) {
        byDay.putIfAbsent(r.day, () => []).add(r);
      }
      setState(() => _byDay = byDay);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// 다른 달 보기. 이번 달이면 오늘을 선택
  void _showMonth(DateTime month) {
    setState(() {
      _month = DateTime(month.year, month.month);
      _selectedDay = _isThisMonth ? _now.day : null;
      _byDay = null;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('독서 캘린더'),
        actions: [
          if (!_isThisMonth)
            TextButton(onPressed: () => _showMonth(_now), child: const Text('오늘')),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _buildMonthHeader(),
              _buildWeekdays(),
              _buildGrid(),
              const SizedBox(height: 8),
              _buildLegend(),
              const SizedBox(height: 20),
              ..._buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _showMonth(DateTime(_month.year, _month.month - 1)),
        ),
        Expanded(
          child: Text(
            '${_month.year}년 ${_month.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _showMonth(DateTime(_month.year, _month.month + 1)),
        ),
      ],
    );
  }

  Widget _buildWeekdays() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final w in _weekdays)
            Expanded(
              child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final byDay = _byDay ?? const <int, List<DayBookTime>>{};
    final blanks = DateTime(_month.year, _month.month, 1).weekday % 7; // 일요일 시작
    final days = DateTime(_month.year, _month.month + 1, 0).day; // 이번 달 마지막 날

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          _DayCell(
            day: d,
            seconds: _sum(byDay[d]),
            selected: d == _selectedDay,
            today: _isThisMonth && d == _now.day,
            onTap: () => setState(() => _selectedDay = d),
          ),
      ],
    );
  }

  Widget _buildLegend() {
    final style = TextStyle(fontSize: 11, color: Colors.grey[600]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final level in _levels) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: amberColor.withValues(alpha: level.alpha)),
          ),
          const SizedBox(width: 4),
          Text(level.label, style: style),
          const SizedBox(width: 10),
        ],
      ],
    );
  }

  /// 이번 달 요약 + 선택한 날짜의 책 목록
  List<Widget> _buildBottom() {
    if (_error != null) {
      return [Text('불러오지 못했어요\n$_error', textAlign: TextAlign.center)];
    }
    final byDay = _byDay;
    if (byDay == null) {
      return const [Center(child: CircularProgressIndicator())];
    }

    final monthTotal = byDay.values.fold<int>(0, (s, items) => s + _sum(items));

    return [
      _MonthSummary(month: _month.month, totalSeconds: monthTotal, readDays: byDay.length),
      const SizedBox(height: 24),
      if (_selectedDay == null)
        Text('날짜를 누르면 그날 읽은 책을 볼 수 있어요', style: TextStyle(color: Colors.grey[600]))
      else
        ..._buildDayDetail(_selectedDay!, byDay[_selectedDay] ?? const []),
    ];
  }

  List<Widget> _buildDayDetail(int day, List<DayBookTime> items) {
    final weekday = _weekdays[DateTime(_month.year, _month.month, day).weekday % 7];
    return [
      Row(
        children: [
          Text('${_month.month}월 $day일 ($weekday)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('합계 ${formatDuration(_sum(items))}'),
        ],
      ),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('이 날은 독서 기록이 없어요', style: TextStyle(color: Colors.grey[600])),
        )
      else
        for (final item in items)
          Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(item.book.author),
              trailing: Text(formatDuration(item.seconds), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
    ];
  }
}

/// 날짜 한 칸. 읽은 날은 호박색(많이 읽을수록 진하게), 선택한 날은 테두리, 오늘은 굵게
class _DayCell extends StatelessWidget {
  final int day;
  final int seconds;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.seconds,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: seconds > 0 ? amberColor.withValues(alpha: _levelAlpha(seconds)) : null,
          border: selected ? Border.all(color: inkColor, width: 2) : null,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: today ? FontWeight.bold : FontWeight.normal,
                color: today ? inkColor : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이번 달 요약: 총 독서 시간, 읽은 날 수
class _MonthSummary extends StatelessWidget {
  final int month;
  final int totalSeconds;
  final int readDays;

  const _MonthSummary({required this.month, required this.totalSeconds, required this.readDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: inkColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _stat('$month월 독서 시간', formatDuration(totalSeconds))),
          Expanded(child: _stat('읽은 날', '$readDays일')),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
