import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/city_list_view.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../domain/entities/user_profile.dart';
import '../../state/auth_provider.dart';
import '../../state/friends_provider.dart';
import '../../state/multiplayer/multiplayer_notifier.dart';
import '../../state/multiplayer/multiplayer_state.dart';
import '../../state/multiplayer/server_url_provider.dart';
import '../../state/wallet_provider.dart';

/// Lobi ekraninin ana alaninda hangi panelin gosterildigini belirler
/// (sadece MpStage.menu asamasindayken anlamlidir).
enum _MenuView {
  /// Sehir siralamasi + en sagda "Arkadaşınla Oyna" karti.
  cities,

  /// "Arkadaşınla Oyna"ya basilinca: solda Oda Kur, sagda Odaya Katil.
  friendChoice,

  /// Oda Kur seçilince: hangi sehirde kurulacagini soran sehir siralamasi.
  createRoomCity,
}

/// Coklu oyunculu giris ekrani: sunucuya baglanir, ana alanda bir sehir
/// secip o sehre girmeye calisan rakiplerle otomatik eslesmeyi (bkz.
/// server/game/roomManager.js joinCityQueue) ya da "Arkadaşınla Oyna"
/// uzerinden oda kurma/katilma akislarini sunar. Her iki yol da secilen
/// sehrin giris ucretini sunucu tarafinda (bkz. server/game/wallet.js)
/// tahsil eder. Esleşme bulununca MultiplayerGameScreen'e gecilir.
class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends ConsumerState<MultiplayerLobbyScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  _MenuView _menuView = _MenuView.cities;

  @override
  void initState() {
    super.initState();
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
    _joinCodeController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  /// Kullanicinin hesabina kayitli, degistirilemez kullanici adi —
  /// coklu oyunculu maclarda/odalarda hep bu isim kullanilir (bkz.
  /// kullanici notu: "Görünen Ad olmayacak, kullanıcı adı kalıcı olacak").
  String get _username => ref.read(authProvider).profile?.username ?? 'Oyuncu';

  void _reconnectWithNewUrl() {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;
    ref.read(serverUrlProvider.notifier).state = url;
    ref.read(multiplayerProvider.notifier).connect(url);
  }

  void _handleBack() {
    if (_menuView != _MenuView.cities) {
      setState(() => _menuView = _MenuView.cities);
      return;
    }
    ref.read(multiplayerProvider.notifier).disconnectAndExit();
    context.pop();
  }

  Future<void> _showInviteDialog(GameInvite invite) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Oda Daveti', style: TextStyle(color: Colors.white)),
        content: Text(
          invite.city != null
              ? '${invite.fromUsername} seni ${invite.city!.name} şehrindeki odasına davet etti.\nGiriş: ${invite.city!.entryFee} RC'
              : '${invite.fromUsername} seni odasına davet etti.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Reddet')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Katıl')),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted == true) {
      ref.read(multiplayerProvider.notifier).acceptInvite(_username);
    } else {
      ref.read(multiplayerProvider.notifier).declineInvite();
    }
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
      if (next.incomingInvite != null && next.incomingInvite != previous?.incomingInvite) {
        _showInviteDialog(next.incomingInvite!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyna'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(state),
                const SizedBox(height: 16),
                Expanded(
                  child: switch (state.stage) {
                    MpStage.menu => _buildMenu(),
                    MpStage.searchingCity => _buildSearching(state),
                    MpStage.roomWaitingForOpponent => _buildRoomWaiting(state),
                    _ => const SizedBox.shrink(),
                  },
                ),
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
    return switch (_menuView) {
      _MenuView.cities => _buildCitiesView(),
      _MenuView.friendChoice => _buildFriendChoiceView(),
      _MenuView.createRoomCity => _buildCreateRoomCityView(),
    };
  }

  /// Ana sehir siralamasi: solda/ortada tum sehirler (yatay, kaydirilabilir),
  /// en sagda sabit "Arkadaşınla Oyna" karti.
  Widget _buildCitiesView() {
    final connected = ref.watch(multiplayerProvider).stage == MpStage.menu;
    final riskCoin = ref.watch(walletProvider).riskCoin;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CityListView(
            scrollDirection: Axis.horizontal,
            riskCoin: riskCoin,
            onSelect: (city) {
              if (!connected) return;
              ref.read(multiplayerProvider.notifier).joinCityQueue(city.id, _username);
            },
          ),
        ),
        SizedBox(
          width: 160,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: PressableScale(
              onTap: connected ? () => setState(() => _menuView = _MenuView.friendChoice) : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.doubleRiskNavy,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, color: Colors.white, size: 32),
                    SizedBox(height: 10),
                    Text(
                      'Arkadaşınla\nOyna',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Arkadaşınla Oyna" secildiginde: solda Oda Kur butonu, sagda Odaya
  /// Katil alanlari.
  Widget _buildFriendChoiceView() {
    final connected = ref.watch(multiplayerProvider).stage == MpStage.menu;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _actionButton(
              label: 'Oda Kur',
              icon: Icons.add_box,
              color: AppColors.doubleRiskNavy,
              onTap: connected ? () => setState(() => _menuView = _MenuView.createRoomCity) : null,
            ),
          ),
        ),
        const VerticalDivider(width: 32, color: Colors.white24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Odaya Katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, letterSpacing: 2),
                  decoration: const InputDecoration(labelText: 'Oda Kodu', filled: true),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  label: 'Katıl',
                  icon: Icons.login,
                  color: AppColors.gold,
                  onTap: connected
                      ? () {
                          final code = _joinCodeController.text.trim();
                          if (code.isEmpty) return;
                          ref.read(multiplayerProvider.notifier).joinRoom(code, _username);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateRoomCityView() {
    final connected = ref.watch(multiplayerProvider).stage == MpStage.menu;
    final riskCoin = ref.watch(walletProvider).riskCoin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => setState(() => _menuView = _MenuView.friendChoice),
            ),
            const Text('Hangi şehirde oda kurmak istersin?', style: TextStyle(color: Colors.white70)),
          ],
        ),
        Expanded(
          child: CityListView(
            scrollDirection: Axis.horizontal,
            riskCoin: riskCoin,
            onSelect: (city) {
              if (!connected) return;
              ref.read(multiplayerProvider.notifier).createRoom(_username, cityId: city.id);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearching(MultiplayerState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.gold),
        const SizedBox(height: 16),
        Text(
          state.city != null ? '${state.city!.name} için rakip aranıyor...' : 'Rakip aranıyor...',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => ref.read(multiplayerProvider.notifier).cancelCityQueue(),
          child: const Text('İptal'),
        ),
      ],
    );
  }

  Widget _buildRoomWaiting(MultiplayerState state) {
    final code = state.roomCode ?? '-----';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.city != null) ...[
                Text(
                  '${state.city!.name} • Giriş: ${state.city!.entryFee} RC • Kazanç: ${state.city!.rewardAmount} RC',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
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
          ),
        ),
        const VerticalDivider(width: 32, color: Colors.white24),
        Expanded(
          flex: 2,
          child: _FriendInviteList(),
        ),
      ],
    );
  }

  /// Sunucu adresi ayari, dar/yatay ekranlarda ana icerigi (sehir listesi)
  /// sikistirmamasi icin ayri bir bottom sheet'te gosterilir (bkz. eskiden
  /// buradaki satir-ici genisleyen panel, dar ekranlarda tasabiliyordu).
  Future<void> _showServerSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gelişmiş: Sunucu Adresi',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Emülatörde varsayılan adres genelde doğrudur. Gerçek bir '
              'telefondan aynı Wi-Fi üzerinden test ederken bilgisayarınızın '
              'yerel ağ IP adresini (örn. http://192.168.1.34:3000), '
              'sunucuyu bir yere deploy ettikten sonra ise oradan aldığınız '
              'https:// adresini girin.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Sunucu Adresi', filled: true),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  _reconnectWithNewUrl();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Bağlan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSettings(MultiplayerState state) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _showServerSettingsSheet,
        child: const Text('Gelişmiş: Sunucu Adresi'),
      ),
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

/// Oda kurulduktan sonra "Rakip bekleniyor" ekraninin sag tarafinda
/// gosterilen, her arkadasin yaninda "Davet Et" butonu olan liste.
class _FriendInviteList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Arkadaşlarım', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Expanded(
          child: friendsState.friends.isEmpty
              ? const Center(
                  child: Text('Arkadaş listen boş.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                )
              : ListView.builder(
                  itemCount: friendsState.friends.length,
                  itemBuilder: (context, index) {
                    final friend = friendsState.friends[index];
                    return _FriendInviteTile(friend: friend);
                  },
                ),
        ),
      ],
    );
  }
}

class _FriendInviteTile extends ConsumerStatefulWidget {
  final UserProfile friend;
  const _FriendInviteTile({required this.friend});

  @override
  ConsumerState<_FriendInviteTile> createState() => _FriendInviteTileState();
}

class _FriendInviteTileState extends ConsumerState<_FriendInviteTile> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
        title: Text(widget.friend.username, style: const TextStyle(color: Colors.white)),
        trailing: TextButton(
          onPressed: _sent
              ? null
              : () {
                  ref.read(multiplayerProvider.notifier).inviteFriend(widget.friend.userId);
                  setState(() => _sent = true);
                },
          child: Text(_sent ? 'Gönderildi' : 'Davet Et'),
        ),
      ),
    );
  }
}
