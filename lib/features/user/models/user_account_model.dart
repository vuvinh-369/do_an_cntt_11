// File: lib/features/user/models/user_account_model.dart

class UserAccountModel {
  final String username;
  final String password;
  final String fullName;
  final DateTime createdAt;
  final String? emailOrPhone;

  const UserAccountModel({
    required this.username,
    required this.password,
    required this.fullName,
    required this.createdAt,
    this.emailOrPhone,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'fullName': fullName,
      'createdAt': createdAt.toIso8601String(),
      'emailOrPhone': emailOrPhone,
    };
  }

  factory UserAccountModel.fromMap(Map<String, dynamic> map) {
    return UserAccountModel(
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      emailOrPhone: map['emailOrPhone'] as String?,
    );
  }

  UserAccountModel copyWith({
    String? username,
    String? password,
    String? fullName,
    DateTime? createdAt,
    String? emailOrPhone,
  }) {
    return UserAccountModel(
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      emailOrPhone: emailOrPhone ?? this.emailOrPhone,
    );
  }
}
