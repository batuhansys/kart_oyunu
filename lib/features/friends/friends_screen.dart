import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';

/// TODO: kullanıcı adına göre arama ve arkadaşlık isteği gönderme, bir
/// backend/veritabanı bağlantısı gerektirir.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Arkadaşlar'),
          bottom: const TabBar(tabs: [Tab(text: 'Arkadaşlarım'), Tab(text: 'İstekler')]),
        ),
        body: GradientBackground(
          child: const TabBarView(
            children: [
              Center(child: Text('Henüz arkadaşınız yok.', style: TextStyle(color: Colors.white70))),
              Center(child: Text('Bekleyen istek yok.', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.gold,
          onPressed: () {},
          child: const Icon(Icons.person_add, color: Colors.black),
        ),
      ),
    );
  }
}
