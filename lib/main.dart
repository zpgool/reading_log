import 'package:flutter/material.dart';

import 'db/database.dart';
import 'router.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await connectDb();
  runApp(const ReadingApp());
}

class ReadingApp extends StatelessWidget {
  const ReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '독서 기록',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: inkColor,
        scaffoldBackgroundColor: paperColor,
        appBarTheme: const AppBarTheme(backgroundColor: paperColor),
      ),
      routerConfig: router,
    );
  }
}
