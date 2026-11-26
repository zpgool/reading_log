/// reading_log 테이블 한 행 (타이머 1회 측정)
class ReadingLog {
  final int logId;
  final int bookId;
  final DateTime startedAt;
  final DateTime? endedAt; // null이면 측정 중

  const ReadingLog({
    required this.logId,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
  });
}
