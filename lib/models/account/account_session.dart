class AccountSession {
  const AccountSession({
    required this.accountId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final String accountId, accessToken, refreshToken;
  final int expiresAt;
  factory AccountSession.fromJson(Map<String, dynamic> data) => AccountSession(
    accountId: data['accountId'] as String,
    accessToken: data['accessToken'] as String,
    refreshToken: data['refreshToken'] as String,
    expiresAt: (data['expiresAt'] as num).toInt(),
  );
  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt,
  };
}
