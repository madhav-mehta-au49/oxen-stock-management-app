/// A user profile stored at `users/{uid}`. Auth credentials live in Firebase Auth;
/// roles and per-user permissions live here.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.name,
    required this.role,
    required this.active,
    required this.permissions,
  });

  final String uid;
  final String email;
  final String username;
  final String name;

  /// `admin` | `store_keeper` | `epc_manager` | `accounts` | `staff`
  final String role;
  final bool active;
  final Map<String, bool> permissions;

  bool get isAdmin => role == 'admin';

  /// Permission check. Admins implicitly have every permission.
  bool can(String permission) => isAdmin || (permissions[permission] ?? false);

  String get displayName =>
      name.isNotEmpty ? name : (username.isNotEmpty ? username : email);

  String get roleLabel => switch (role) {
    'admin' => 'Administrator',
    'store_keeper' => 'Store Keeper',
    'epc_manager' => 'EPC Manager',
    'accounts' => 'Accounts (read only)',
    _ => 'Staff',
  };

  Map<String, dynamic> toMap() => {
    'email': email,
    'username': username,
    'name': name,
    'role': role,
    'active': active,
    'permissions': permissions,
  };

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final raw = (data['permissions'] as Map?) ?? const {};
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      username: data['username'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? 'staff',
      active: data['active'] as bool? ?? true,
      permissions: {
        for (final e in raw.entries) e.key.toString(): e.value == true,
      },
    );
  }

  AppUser copyWith({
    String? name,
    String? role,
    bool? active,
    Map<String, bool>? permissions,
  }) => AppUser(
    uid: uid,
    email: email,
    username: username,
    name: name ?? this.name,
    role: role ?? this.role,
    active: active ?? this.active,
    permissions: permissions ?? this.permissions,
  );
}

/// Permission keys + labels for the admin UI.
const List<(String, String)> kPermissionDefs = [
  ('itemCreate', 'Create items'),
  ('itemEdit', 'Edit items'),
  ('itemDelete', 'Delete items'),
  ('stockIn', 'Stock In'),
  ('stockOut', 'Stock Out'),
  ('challanCreate', 'Create challans'),
  ('challanEdit', 'Edit challans'),
  ('challanDelete', 'Cancel challans'),
  ('customerCreate', 'Create customers'),
  ('customerEdit', 'Edit customers'),
  ('customerDelete', 'Delete customers'),
  ('categoryCreate', 'Create categories'),
  ('categoryEdit', 'Edit categories'),
  ('categoryDelete', 'Delete categories'),
  ('settingsChange', 'Change settings'),
];

const List<String> kRoleDefs = [
  'admin',
  'store_keeper',
  'epc_manager',
  'accounts',
];
