/// Employee profile stored at `users/{uid}` (credentials live in Firebase Auth).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
  });

  final String uid;
  final String email;
  final String name;

  /// `admin` | `staff` | `viewer`
  final String role;
  final bool active;

  bool get isAdmin => role == 'admin';
  bool get canWrite => role != 'viewer';

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
        'active': active,
      };

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
        uid: uid,
        email: data['email'] as String? ?? '',
        name: data['name'] as String? ?? '',
        role: data['role'] as String? ?? 'staff',
        active: data['active'] as bool? ?? true,
      );
}
