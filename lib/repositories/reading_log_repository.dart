import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/reading_log.dart';

/// reading_log 테이블 SQL: 타이머 시작·일시정지·종료, 캘린더(날짜별 독서 시간) 조회
class ReadingLogRepository {
  static const _columns = 'log_id, book_id, started_at, ended_at';

  ReadingLog _toLog(ResultRow r) => ReadingLog(
        logId: r[0] as int,
        bookId: r[1] as int,
        startedAt: r[2] as DateTime,
        endedAt: r[3] as DateTime?,
      );

  /// 측정 중인 기록 (ended_at이 NULL). 앱을 다시 켜도 이어서 측정하기 위해 사용
  Future<ReadingLog?> findRunning() async {
    final rows = await db.execute('''
      SELECT $_columns FROM reading_log
      WHERE ended_at IS NULL
      ORDER BY started_at DESC
      LIMIT 1
    ''');
    return rows.isEmpty ? null : _toLog(rows.first);
  }

  /// 시작·다시 시작: 새 기록 추가 (started_at은 DB의 DEFAULT now())
  Future<ReadingLog> start(int bookId) async {
    final rows = await db.execute(
      Sql.named('INSERT INTO reading_log (book_id) VALUES (@bookId) RETURNING $_columns'),
      parameters: {'bookId': bookId},
    );
    return _toLog(rows.first);
  }

  /// 일시정지·종료: ended_at 저장 후 이번 구간의 독서 시간(초)을 돌려준다
  Future<int> stop(int logId) async {
    final rows = await db.execute(
      Sql.named('''
        UPDATE reading_log SET ended_at = now()
        WHERE log_id = @logId AND ended_at IS NULL
        RETURNING EXTRACT(EPOCH FROM ended_at - started_at)::int
      '''),
      parameters: {'logId': logId},
    );
    return rows.isEmpty ? 0 : rows.first[0] as int;
  }

  /// 오늘(한국 시간) 이 책의 기록
  Future<List<ReadingLog>> findToday(int bookId) async {
    final rows = await db.execute(
      Sql.named('''
        SELECT $_columns FROM reading_log
        WHERE book_id = @bookId
          AND (started_at AT TIME ZONE 'Asia/Seoul')::date = (now() AT TIME ZONE 'Asia/Seoul')::date
        ORDER BY started_at
      '''),
      parameters: {'bookId': bookId},
    );
    return rows.map(_toLog).toList();
  }

  /// 오늘(한국 시간) 모든 책의 독서 시간(초). 측정 중인 기록은 지금까지 읽은 만큼 포함
  Future<int> todaySeconds() async {
    final rows = await db.execute('''
      SELECT COALESCE(SUM(EXTRACT(EPOCH FROM COALESCE(ended_at, now()) - started_at)), 0)::int
      FROM reading_log
      WHERE (started_at AT TIME ZONE 'Asia/Seoul')::date = (now() AT TIME ZONE 'Asia/Seoul')::date
    ''');
    return rows.first[0] as int;
  }
}
