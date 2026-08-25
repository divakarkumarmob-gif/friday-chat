class Contact {
  final String id;
  final String name;
  final String status;
  final String? avatarUrl;
  final String phoneNumber;
  final bool isOnline;

  const Contact({
    required this.id,
    required this.name,
    required this.status,
    this.avatarUrl,
    required this.phoneNumber,
    this.isOnline = false,
  });
}
