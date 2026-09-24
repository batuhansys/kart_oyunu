import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../state/auth_provider.dart';
import '../../state/multiplayer/multiplayer_notifier.dart';
import '../../state/multiplayer/multiplayer_state.dart';
import '../../state/multiplayer/server_url_provider.dart';

/// Coklu oyunculu giris ekrani: sunucuya baglanir, "Hizli Eslesme",
/// "Oda Kur" (arkadasa kod gonder) ve "Odaya Katil" (kod ile) akislarini
/// sunar. Esleşme bulununca MultiplayerGameScreen'e gecilir.
class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends ConsumerState<MultiplayerLobbyScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  bool _showServerSettings = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _nameController = TextEditingController(text: profile?.username ?? 'Oyuncu');
    _serverUrlController.text = ref.read(serverUrlProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(multiplayerProvider.notifier);
      if (ref.read(multiplayerProvider).stage == MpStage.disconnected) {
        notifier.connect(ref.read(serverUrlProvider));
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _joinCodeController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  String get _playerName => _nameController.text.trim().isEmpty ? 'Oyuncu' : _nameController.text.trim();

  void _reconnectWithNewUrl() {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;
    ref.read(serverUrlProvider.notifier).state = url;
    ref.read(multiplayerProvider.notifier).connect(url);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerProvider);

    ref.listen<MultiplayerState>(multiplayerProvider, (previous, next) {
      if (previous?.stage != MpStage.playing && next.stage == MpStage.playing) {
        context.push('/multiplayer/game');
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.foldRed),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çevrimiçi Oyna'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(multiplayerProvider.notifier).disconnectAndExit();
            context.pop();
          },
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(state),
                const SizedBox(height: 20),
                if (state.stage == MpStage.menu) _buildMenu(),
                if (state.stage == MpStage.searchingQuickMatch) _buildSearching(),
                if (state.stage == MpStage.roomWaitingForOpponent) _buildRoomWaiting(state),
                const SizedBox(height: 24),
                _buildServerSettings(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(MultiplayerState state) {
    late final String text;
    late final Color color;
    switch (state.stage) {
      case MpStage.disconnected:
        text = state.errorMessage ?? 'Sunucuya bağlı değil.';
        color = AppColors.foldRed;
        break;
      case MpStage.connecting:
        text = 'Sunucuya bağlanılıyor...';
        color = AppColors.passGray;
        break;
      default:
        text = 'Sunucuya bağlı.';
        color = Colors.greenAccent.shade400;
    }
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
        if (state.stage == MpStage.disconnected)
          TextButton(
            onPressed: () => ref.read(multiplayerProvider.notifier).connect(ref.read(serverUrlProvider)),
            child: const Text('Tekrar Dene'),
          ),
      ],
    );
  }

  Widget _buildMenu() {
    final connected = ref.watch(multiplayerProvider).stage == MpStage.menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Görünen adın', filled: true),
        ),
        const SizedBox(height: 20),
        _actionButton(
          label: 'Hızlı Eşleşme',
          icon: Icons.flash_on,
          color: AppColors.riskBlue,
          onTap: connected ? () => ref.read(multiplayerProvider.notifier).quickMatch(_playerName) : null,
        ),
        const SizedBox(height: 12),
        _actionButton(
          label: 'Oda Kur (Arkadaşla Oyna)',
          icon: Icons.add_box,
          color: AppColors.doubleRiskNavy,
          onTap: connected ? () => ref.read(multiplayerProvider.notifier).createRoom(_playerName) : null,
        ),
        const SizedBox(height: 20),
        Text('veya bir oda koduna katıl', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: const InputDecoration(labelText: 'Oda Kodu', filled: true),
              ),
            ),
            const SizedBox(width: 12),
            PressableScale(
              onTap: connected
                  ? () {
                      final code = _joinCodeController.text.trim();
                      if (code.isEmpty) return;
                      ref.read(multiplayerProvider.notifier).joinRoom(code, _playerName);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: connected ? AppColors.gold : AppColors.gold.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Katıl', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearching() {
    return Column(
      children: [
        const CircularProgressIndicator(color: AppColors.gold),
        const SizedBox(height: 16),
        const Text('Rakip aranıyor...', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => ref.read(multiplayerProvider.notifier).cancelQuickMatch(),
          child: const Text('İptal'),
        ),
      ],
    );
  }

  Widget _buildRoomWaiting(MultiplayerState state) {
    final code = state.roomCode ?? '-----';
    return Column(
      children: [
        const Text('Bu kodu arkadaşınla paylaş:', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Text(
            code,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Kodu Kopyala'),
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: AppColors.gold),
        const SizedBox(height: 16),
        const Text('Rakip bekleniyor...', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => ref.read(multiplayerProvider.notifier).leaveTable(),
          child: const Text('İptal'),
        ),
      ],
    );
  }

  Widget _buildServerSettings(MultiplayerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: () => setState(() => _showServerSettings = !_showServerSettings),
          child: Text(_showServerSettings ? 'Sunucu Ayarlarını Gizle' : 'Gelişmiş: Sunucu Adresi'),
        ),
        if (_showServerSettings) ...[
          const Text(
            'Emülatörde varsayılan adres genelde doğrudur. Gerçek bir '
            'telefondan aynı Wi-Fi üzerinden test ederken bilgisayarınızın '
            'yerel ağ IP adresini (örn. http://192.168.1.34:3000), '
            'sunucuyu bir yere deploy ettikten sonra ise oradan aldığınız '
            'https:// adresini girin.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _serverUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Sunucu Adresi', filled: true),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _reconnectWithNewUrl, child: const Text('Bağlan')),
          ),
        ],
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: disabled ? color.withOpacity(0.3) : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? null
              : [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
