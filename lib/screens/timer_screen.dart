import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/book.dart';
import '../models/reading_log.dart';
import '../repositories/book_repository.dart';
import '../repositories/reading_log_repository.dart';
import '../utils.dart';

/// 독서 타이머: 책 선택 후 시작·일시정지·종료
///
/// 시작·다시 시작 = reading_log 새 행, 일시정지·종료 = 그 행의 ended_at 저장.
/// 화면의 시간은 이번 독서(시작~종료) 동안 쌓인 시간.
class TimerScreen extends StatefulWidget {
  final int? bookId; // 내 서재에서 고른 책

  const TimerScreen({super.key, this.bookId});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _bookRepo = BookRepository();
  final _logRepo = ReadingLogRepository();

  List<Book>? _books; // null이면 불러오는 중
  Object? _error;
  int? _bookId;

  ReadingLog? _running; // 측정 중인 기록 (ended_at이 NULL인 행)
  int _sessionDone = 0; // 이번 독서에서 일시정지로 끝난 구간들의 합(초)
  List<ReadingLog> _today = [];

  Timer? _ticker; // 측정 중 1초마다 화면 갱신
  bool _busy = false; // DB 작업 중 버튼 연타 방지

  bool get _isRunning => _running != null;
  bool get _inSession => _isRunning || _sessionDone > 0; // 시작 후 종료 전

  int _runningSeconds() =>
      _running == null ? 0 : DateTime.now().difference(_running!.startedAt).inSeconds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final books = (await _bookRepo.findAllWithTotal()).map((s) => s.book).toList();
      final running = await _logRepo.findRunning();

      int? bookId;
      if (running != null) {
        bookId = running.bookId; // 측정 중인 기록이 있으면 그 책으로 이어서
      } else if (books.any((b) => b.bookId == widget.bookId)) {
        bookId = widget.bookId;
      } else if (books.isNotEmpty) {
        bookId = books.first.bookId;
      }

      final today = bookId == null ? <ReadingLog>[] : await _logRepo.findToday(bookId);
      if (!mounted) return;
      setState(() {
        _books = books;
        _bookId = bookId;
        _running = running;
        _today = today;
      });
      if (running != null) _startTicker();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _reloadToday() async {
    final today = await _logRepo.findToday(_bookId!);
    if (mounted) setState(() => _today = today);
  }

  /// DB 작업 공통 처리: 연타 방지 + 오류 메시지
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _showMessage('저장하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// 시작·다시 시작
  Future<void> _start() => _run(() async {
        final log = await _logRepo.start(_bookId!);
        setState(() => _running = log);
        _startTicker();
        await _reloadToday();
      });

  /// 측정 중인 구간 끝내기 (일시정지·종료 공통)
  Future<void> _stopRunning() async {
    final seconds = await _logRepo.stop(_running!.logId);
    _ticker?.cancel();
    setState(() {
      _sessionDone += seconds;
      _running = null;
    });
  }

  Future<void> _pause() => _run(() async {
        await _stopRunning();
        await _reloadToday();
      });

  /// 종료: 2차 확인 후 이번 독서 마무리
  Future<void> _finish() async {
    final ok = await confirmDialog(
      context,
      title: '이번 독서를 종료할까요?',
      message: '지금까지 ${formatTimer(_sessionDone + _runningSeconds())} 읽었어요.\n'
          '종료하면 기록이 저장되고 타이머가 0으로 돌아가요.',
      confirmText: '종료',
      cancelText: _isRunning ? '계속 읽기' : '취소',
    );
    if (!ok || !mounted) return;

    await _run(() async {
      if (_isRunning) await _stopRunning();
      final total = _sessionDone;
      setState(() => _sessionDone = 0);
      await _reloadToday();
      if (!mounted) return;
      _showMessage('이번 독서 ${formatDuration(total)}을 기록했어요');
    });
  }

  Future<void> _selectBook(int bookId) async {
    setState(() {
      _bookId = bookId;
      _today = [];
    });
    await _reloadToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('독서 타이머')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text('불러오지 못했어요\n$_error', textAlign: TextAlign.center));
    if (_books == null) return const Center(child: CircularProgressIndicator());
    if (_books!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('먼저 내 서재에서 책을 등록해 주세요.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/library'), child: const Text('내 서재로')),
          ],
        ),
      );
    }

    final todayDone = _today
        .where((l) => l.endedAt != null)
        .fold(0, (sum, l) => sum + l.endedAt!.difference(l.startedAt).inSeconds);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 책 선택 (이번 독서를 종료하기 전에는 바꿀 수 없음)
        DropdownButtonFormField<int>(
          initialValue: _bookId,
          decoration: InputDecoration(
            labelText: '읽을 책',
            helperText: _inSession ? '종료한 뒤에 다른 책을 고를 수 있어요' : null,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          items: [
            for (final b in _books!)
              DropdownMenuItem(value: b.bookId, child: Text('${b.title} · ${b.author}')),
          ],
          onChanged: _inSession ? null : (id) => _selectBook(id!),
        ),
        const SizedBox(height: 32),
        _TimerDial(
          seconds: _sessionDone + _runningSeconds(),
          state: _isRunning ? '읽는 중' : (_inSession ? '일시정지' : '준비'),
          running: _isRunning,
        ),
        const SizedBox(height: 28),
        _buildButtons(),
        const SizedBox(height: 36),
        Row(
          children: [
            const Text('오늘 이 책 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('합계 ${formatDuration(todayDone + _runningSeconds())}'),
          ],
        ),
        const SizedBox(height: 8),
        if (_today.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('오늘은 아직 기록이 없어요', style: TextStyle(color: Colors.grey[600])),
          )
        else
          for (final log in _today.reversed) _LogTile(log: log),
      ],
    );
  }

  Widget _buildButtons() {
    final onStart = _busy ? null : _start;
    final onPause = _busy ? null : _pause;
    final onFinish = _busy ? null : _finish;

    final List<Widget> buttons;
    if (_isRunning) {
      buttons = [
        FilledButton.tonalIcon(onPressed: onPause, icon: const Icon(Icons.pause), label: const Text('일시정지')),
        OutlinedButton.icon(onPressed: onFinish, icon: const Icon(Icons.stop), label: const Text('종료')),
      ];
    } else if (_inSession) {
      buttons = [
        FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: const Text('다시 시작')),
        OutlinedButton.icon(onPressed: onFinish, icon: const Icon(Icons.stop), label: const Text('종료')),
      ];
    } else {
      buttons = [
        FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: const Text('시작')),
      ];
    }

    return Wrap(alignment: WrapAlignment.center, spacing: 12, children: buttons);
  }
}

/// 원형 타이머 표시. 측정 중이면 호박색 테두리
class _TimerDial extends StatelessWidget {
  final int seconds;
  final String state;
  final bool running;

  const _TimerDial({required this.seconds, required this.state, required this.running});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: running ? amberColor : inkColor.withValues(alpha: 0.25), width: 10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatTimer(seconds),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(state, style: TextStyle(color: running ? amberColor : Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// 오늘 기록 한 줄: "20:00 – 20:30   30분" / "21:10 – 측정 중"
class _LogTile extends StatelessWidget {
  final ReadingLog log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final end = log.endedAt;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(end == null ? Icons.timer : Icons.check_circle_outline,
            color: end == null ? amberColor : inkColor),
        title: Text('${formatClock(log.startedAt)} – ${end == null ? '측정 중' : formatClock(end)}'),
        trailing: end == null
            ? null
            : Text(formatDuration(end.difference(log.startedAt).inSeconds),
                style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
