import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/user_profile.dart';
import '../../state/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  Future<void> _showAddFriendDialog() async {
    final controller = TextEditingController();
    String? errorText;
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              title: const Text('Arkadaş Ekle', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tam kullanıcı adı',
                      filled: true,
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Vazgeç'),
                ),
                TextButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final username = controller.text.trim();
                          if (username.isEmpty) return;
                          setDialogState(() => isSending = true);
                          final result = await ref
                              .read(friendsProvider.notifier)
                              .searchAndSendRequest(username);
                          result.when(
                            success: (_) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$username\'e istek gönderildi.')),
                              );
                            },
                            failure: (message) {
                              setDialogState(() {
                                isSending = false;
                                errorText = message;
                              });
                            },
                          );
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('İstek Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Arkadaşlar'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Arkadaş Ekle',
              onPressed: _showAddFriendDialog,
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Arkadaşlarım'),
              Tab(text: 'İstekler${state.incomingRequests.isEmpty ? '' : ' (${state.incomingRequests.length})'}'),
            ],
          ),
        ),
        body: GradientBackground(
          child: RefreshIndicator(
            onRefresh: () => ref.read(friendsProvider.notifier).refresh(),
            child: TabBarView(
              children: [
                _FriendsListTab(state: state),
                _RequestsTab(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsListTab extends StatelessWidget {
  final FriendsState state;
  const _FriendsListTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (state.friends.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Henüz arkadaşınız yok.', style: TextStyle(color: Colors.white70))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.friends.length,
      itemBuilder: (context, index) {
        final friend = state.friends[index];
        return _ProfileTile(profile: friend);
      },
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  final FriendsState state;
  const _RequestsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.incomingRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (state.incomingRequests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Bekleyen istek yok.', style: TextStyle(color: Colors.white70))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.incomingRequests.length,
      itemBuilder: (context, index) {
        final request = state.incomingRequests[index];
        return _RequestTile(request: request);
      },
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileTile({required this.profile});

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Arkadaşlıktan Çıkar', style: TextStyle(color: Colors.white)),
        content: Text(
          '${profile.username} arkadaş listenden çıkarılsın mı?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Çıkar', style: TextStyle(color: AppColors.foldRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(friendsProvider.notifier).removeFriend(profile.userId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(profile.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Seviye ${profile.level}', style: const TextStyle(color: Colors.white60)),
        trailing: IconButton(
          icon: Icon(Icons.person_remove, color: AppColors.foldRed),
          tooltip: 'Arkadaşlıktan Çıkar',
          onPressed: () => _confirmRemove(context, ref),
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final IncomingFriendRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(request.fromProfile.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Arkadaşlık isteği gönderdi', style: TextStyle(color: Colors.white60)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              onPressed: () => ref.read(friendsProvider.notifier).respond(request.requestId, accept: true),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: AppColors.foldRed),
              onPressed: () => ref.read(friendsProvider.notifier).respond(request.requestId, accept: false),
            ),
          ],
        ),
      ),
    );
  }
}
