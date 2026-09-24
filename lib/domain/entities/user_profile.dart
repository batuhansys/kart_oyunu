class UserProfile {
  final String username;
  final String userId;
  final int level;
  final int xp;
  final String avatarAsset;

  const UserProfile({
    required this.username,
    required this.userId,
    this.level = 1,
    this.xp = 0,
    this.avatarAsset = 'assets/avatars/avatar_1.png',
  });

  UserProfile copyWith({int? level, int? xp, String? avatarAsset}) {
    return UserProfile(
      username: username,
      userId: userId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      avatarAsset: avatarAsset ?? this.avatarAsset,
    );
  }
}
