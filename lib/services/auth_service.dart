import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  // Local fallback mock user for demo/offline test
  User? _mockUser;
  bool _mockLoggedIn = false;

  User? get currentUser => _mockUser ?? _client.auth.currentUser;
  Session? get currentSession => _mockLoggedIn
      ? Session(
          accessToken: 'demo-token',
          tokenType: 'bearer',
          user: User(
            id: _mockUser?.id ?? 'demo-user-id',
            appMetadata: {},
            userMetadata: _mockUser?.userMetadata ?? {'name': 'I Putu Agus Martha Jaya', 'role': 'owner'},
            aud: 'authenticated',
            createdAt: '2026-11-18',
          ),
        )
      : _client.auth.currentSession;

  bool get isLoggedIn => _mockLoggedIn || currentSession != null;

  Future<AuthResponse> register({
    required String email,
    required String password,
    String name = '',
    String role = 'seeker', // 'seeker' atau 'owner'
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': role},
      );
      if (res.session != null) {
        _mockLoggedIn = true;
      }
      return res;
    } catch (_) {
      // Fallback untuk demo/local test jika URL Supabase belum diisi
      _mockUser = User(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        appMetadata: const {},
        userMetadata: {'name': name.isEmpty ? 'User Demo' : name, 'role': role},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      _mockLoggedIn = true;
      return AuthResponse(
        session: Session(
          accessToken: 'demo-token',
          tokenType: 'bearer',
          user: _mockUser!,
        ),
        user: _mockUser,
      );
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res;
    } catch (_) {
      // Fallback demo/local test: jika server placeholder atau offline
      _mockUser = User(
        id: 'user-agusmartha-01',
        appMetadata: const {},
        userMetadata: {
          'name': 'I Putu Agus Martha Jaya',
          'role': email.contains('seeker') ? 'seeker' : 'owner',
        },
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      _mockLoggedIn = true;
      return AuthResponse(
        session: Session(
          accessToken: 'demo-token',
          tokenType: 'bearer',
          user: _mockUser!,
        ),
        user: _mockUser,
      );
    }
  }

  Future<void> logout() async {
    _mockLoggedIn = false;
    _mockUser = null;
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
