import 'package:flutter/material.dart';

import '../../core/widgets/gradient_background.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: const GradientBackground(
        child: Center(
          child: Text('Bildiriminiz yok.', style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}
