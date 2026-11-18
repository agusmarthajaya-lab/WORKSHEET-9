import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String role; // seeker | owner | admin

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isSeeker => role == 'seeker';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] as String,
        email: (m['email'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        role: (m['role'] ?? 'seeker') as String,
      );
}

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> getMyProfile() async {
    final user = AuthService.instance.currentUser ?? _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) return UserProfile.fromMap(data);
    } catch (_) {}

    // Fallback profile dari metadata user
    final meta = user.userMetadata ?? {};
    return UserProfile(
      id: user.id,
      email: user.email ?? 'agusmartha@undiksha.ac.id',
      name: (meta['name'] as String?)?.isNotEmpty == true
          ? meta['name'] as String
          : 'I Putu Agus Martha Jaya',
      role: (meta['role'] as String?) ?? 'owner',
    );
  }
}
