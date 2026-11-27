import 'dart:io';

import 'package:postgres/postgres.dart';

/// 앱 전체에서 쓰는 PostgreSQL 연결
late final Connection db;

/// 앱 시작 시 한 번 호출
Future<void> connectDb() async {
  db = await Connection.open(
    Endpoint(
      // Android 에뮬레이터에서는 Mac의 localhost가 10.0.2.2
      host: Platform.isAndroid ? '10.0.2.2' : 'localhost',
      database: 'reading_app',
      username: 'jeho',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}
