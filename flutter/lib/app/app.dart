import 'package:flutter/material.dart';

/// Root widget of the Helix Flutter app (driver + admin shells).
class HelixApp extends StatelessWidget {
  const HelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helix',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(
        body: Center(child: Text('Helix — loading...')),
      ),
    );
  }
}
