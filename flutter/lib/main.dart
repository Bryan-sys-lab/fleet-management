import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = await AppContainer.create(prefs);
  runApp(
    ProviderScope(
      overrides: [containerProvider.overrideWithValue(container)],
      child: const HelixApp(),
    ),
  );
}
