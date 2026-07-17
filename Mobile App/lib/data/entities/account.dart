class Account {
  final String id;
  final String displayName;
  final List<String> roles;
  final String? email;
  final String? locale;
  final String? timezone;

  const Account({
    required this.id,
    required this.displayName,
    required this.roles,
    this.email,
    this.locale,
    this.timezone,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    roles: (json['roles'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    email: json['email'] as String?,
    locale: json['locale'] as String?,
    timezone: json['timezone'] as String?,
  );
}
