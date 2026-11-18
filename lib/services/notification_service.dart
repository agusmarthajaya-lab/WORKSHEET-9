import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_keys.dart';
import '../firebase_options.dart';
import '../pages/kos_detail_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[BACKGROUND] Firebase init error: $e');
  }
  debugPrint('[BACKGROUND] ${message.notification?.title}');
  debugPrint('[BACKGROUND] ${message.notification?.body}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _lastToken;

  String? get currentToken => _lastToken;

  /// Meminta izin notifikasi dan mengembalikan statusnya:
  /// authorized | provisional | denied | notDetermined
  Future<AuthorizationStatus> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Notification permission: ${settings.authorizationStatus.name}');
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('requestPermission warning/fallback: $e');
      return AuthorizationStatus.authorized;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      _lastToken = token;
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      final fallbackToken = 'DEMO_FCM_TOKEN_${DateTime.now().millisecondsSinceEpoch}';
      _lastToken = fallbackToken;
      debugPrint('FCM Token (local/fallback): $fallbackToken ($e)');
      return fallbackToken;
    }
  }

  /// Token dapat berubah, sehingga perubahan perlu didengarkan.
  void listenTokenRefresh(void Function(String token) onRefresh) {
    try {
      _messaging.onTokenRefresh.listen((newToken) {
        _lastToken = newToken;
        debugPrint('FCM Token diperbarui: $newToken');
        onRefresh(newToken);
      });
    } catch (e) {
      debugPrint('listenTokenRefresh warning: $e');
    }
  }

  /// Simpan token ke Supabase (Device Registration)
  Future<void> saveTokenToSupabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('device_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Token tersimpan di Supabase device_tokens: $token');
    } catch (e) {
      debugPrint('saveTokenToSupabase: $e');
    }
  }

  Future<void> init() async {
    await requestPermission();
    final token = await getToken();
    if (token != null) await saveTokenToSupabase(token); // opsional
    listenTokenRefresh(saveTokenToSupabase); // opsional

    try {
      // iOS: tampilkan banner saat aplikasi di foreground
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('setForegroundNotificationPresentationOptions warning: $e');
    }

    // FOREGROUND: aplikasi sedang terbuka
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FOREGROUND] Notification received');
      debugPrint('title: ${message.notification?.title}');
      debugPrint('body : ${message.notification?.body}');
      debugPrint('data : ${message.data}');

      // Android/Web tidak menampilkan notifikasi sistem saat foreground,
      // jadi tampilkan sendiri di dalam aplikasi.
      final title = message.notification?.title ?? 'Notifikasi';
      final body = message.notification?.body ?? '';
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          action: message.data.containsKey('kos_id')
              ? SnackBarAction(
                  label: 'Buka',
                  onPressed: () => _handleTap(message),
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  // Bonus: Interaksi Notifikasi
  Future<void> setupInteractedMessage() async {
    try {
      // Aplikasi TERMINATED lalu dibuka dari notifikasi
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);

      // Aplikasi BACKGROUND lalu dibuka dari notifikasi
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    } catch (e) {
      debugPrint('setupInteractedMessage warning: $e');
    }
  }

  void _handleTap(RemoteMessage message) {
    final kosId = message.data['kos_id'];
    if (kosId == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => KosDetailPage(kosId: kosId.toString()),
      ),
    );
  }

  /// Simulasi notifikasi untuk pengujian lokal / demo di Chrome
  void simulateNotification({
    required String title,
    required String body,
    String? kosId,
  }) {
    debugPrint('[SIMULATION] Menerima notifikasi uji');
    debugPrint('title: $title');
    debugPrint('body : $body');

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.indigo.shade800,
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$title\n$body',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        action: kosId != null
            ? SnackBarAction(
                label: 'Lihat Kos',
                textColor: Colors.amberAccent,
                onPressed: () {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => KosDetailPage(kosId: kosId),
                    ),
                  );
                },
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
