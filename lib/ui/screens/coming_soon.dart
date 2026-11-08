import 'package:flutter/material.dart';

import '../theme.dart';

/// 아직 이식하지 않은 화면에 보여주는 안내.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
