import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/book_repository.dart';
import '../utils.dart';

/// 내 서재: 등록한 책과 누적 독서 시간, 책 등록
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _repo = BookRepository();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  List<BookSummary>? _books; // null이면 아직 불러오는 중
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// DB에서 서재 목록 다시 불러오기
  Future<void> _load() async {
    try {
      final books = await _repo.findAllWithTotal();
      if (!mounted) return;
      setState(() {
        _books = books;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddBookSheet(),
    );
    if (result == null) return;

    final (title, author) = result;
    try {
      final book = await _repo.addBook(title, author);
      if (!mounted) return;
      // DB가 돌려준 새 책을 목록 맨 위에 바로 추가 (새 책은 독서 시간 0)
      setState(() => _books = [(book: book, totalSeconds: 0), ...?_books]);
      _showMessage('「$title」을(를) 서재에 추가했어요');
    } catch (e) {
      if (!mounted) return;
      _showMessage('등록하지 못했어요: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _books ?? const <BookSummary>[];
    final total = books.fold(0, (sum, b) => sum + b.totalSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('내 서재')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('책 등록'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // 고정 영역: 요약 카드
            const SizedBox(height: 8),
            _SummaryCard(totalSeconds: total, bookCount: books.length),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('독서 목록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: '새로고침',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshKey.currentState?.show(),
                ),
              ],
            ),
            // 새로고침 영역: 목록만 당겨서 새로고침
            Expanded(
              child: RefreshIndicator(
                key: _refreshKey,
                onRefresh: _load,
                child: ScrollConfiguration(
                  // 데스크톱에서도 마우스·트랙패드로 당겨서 새로고침
                  behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  }),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      if (_error != null)
                        _Message('불러오지 못했어요\n$_error')
                      else if (_books == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (books.isEmpty)
                        const _Message('아직 등록한 책이 없어요.\n오른쪽 아래 버튼으로 첫 책을 등록해 보세요.')
                      else
                        for (final b in books) _BookTile(summary: b),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
    );
  }
}

/// 상단 요약: 총 독서 시간, 등록한 책 수
class _SummaryCard extends StatelessWidget {
  final int totalSeconds;
  final int bookCount;

  const _SummaryCard({required this.totalSeconds, required this.bookCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: inkColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('총 독서 시간', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            formatDuration(totalSeconds),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('등록한 책 $bookCount권', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

/// 책 한 권: 제목/저자 + 누적 시간. 누르면 그 책으로 타이머 열기
class _BookTile extends StatelessWidget {
  final BookSummary summary;

  const _BookTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final book = summary.book;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 8),
        title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(book.author),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatDuration(summary.totalSeconds), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () => context.go('/timer?bookId=${book.bookId}'),
      ),
    );
  }
}

/// 책 등록 하단 시트: 제목·저자 입력 (DB 컬럼 길이에 맞춰 100자/50자 제한)
class _AddBookSheet extends StatefulWidget {
  const _AddBookSheet();

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? '입력해 주세요' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (_title.text.trim(), _author.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('책 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _author,
              maxLength: 50,
              decoration: const InputDecoration(labelText: '저자', border: OutlineInputBorder()),
              validator: _required,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('등록')),
          ],
        ),
      ),
    );
  }
}
