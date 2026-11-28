import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/book.dart';

/// 서재 목록 한 줄: 책 + 누적 독서 시간(초)
typedef BookSummary = ({Book book, int totalSeconds});

/// book 테이블 SQL: 책 등록, 내 서재(책별 누적 독서 시간) 조회
class BookRepository {
  /// 책 등록 후 DB에 저장된 행(새 book_id 포함)을 돌려준다
  Future<Book> addBook(String title, String author) async {
    final rows = await db.execute(
      Sql.named('INSERT INTO book (title, author) VALUES (@title, @author) '
          'RETURNING book_id, title, author'),
      parameters: {'title': title, 'author': author},
    );
    final r = rows.first;
    return Book(bookId: r[0] as int, title: r[1] as String, author: r[2] as String);
  }

  /// 모든 책과 책별 누적 독서 시간 (끝난 기록만 합산, 새로 등록한 책이 위)
  Future<List<BookSummary>> findAllWithTotal() async {
    final rows = await db.execute('''
      SELECT b.book_id, b.title, b.author,
             COALESCE(SUM(EXTRACT(EPOCH FROM r.ended_at - r.started_at)), 0)::int AS total_sec
      FROM book b
      LEFT JOIN reading_log r
             ON r.book_id = b.book_id AND r.ended_at IS NOT NULL
      GROUP BY b.book_id
      ORDER BY b.book_id DESC
    ''');

    return rows
        .map((r) => (
              book: Book(
                bookId: r[0] as int,
                title: r[1] as String,
                author: r[2] as String,
              ),
              totalSeconds: r[3] as int,
            ))
        .toList();
  }
}
