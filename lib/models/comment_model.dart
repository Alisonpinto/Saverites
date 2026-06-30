class CommentModel {
  final String id;
  final String postId;
  final String username;
  final String avatarSeed;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final bool isLikedByMe;

  CommentModel({
    required this.id,
    required this.postId,
    required this.username,
    required this.avatarSeed,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  CommentModel copyWith({
    int? likesCount,
    bool? isLikedByMe,
  }) {
    return CommentModel(
      id: id,
      postId: postId,
      username: username,
      avatarSeed: avatarSeed,
      text: text,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'username': username,
        'avatarSeed': avatarSeed,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'likesCount': likesCount,
        'isLikedByMe': isLikedByMe,
      };

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        id: (json['id'] ?? json['comment_id'] ?? '').toString(),
        postId: (json['postId'] ?? json['post_id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        avatarSeed: (json['avatarSeed'] ?? json['avatar_seed'] ?? 'memoria').toString(),
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
        likesCount: json['likesCount'] as int? ?? json['likes_count'] as int? ?? 0,
        isLikedByMe: json['isLikedByMe'] as bool? ?? json['is_liked_by_me'] as bool? ?? false,
      );
}
