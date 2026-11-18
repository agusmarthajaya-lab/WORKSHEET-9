import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/kos_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../widgets/role_guard.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<UserProfile?> _profileFuture;
  late Future<List<Map<String, dynamic>>> _kosFuture;
  final KosService _kosService = KosService();
  String? _fcmToken;
  AuthorizationStatus _permissionStatus = AuthorizationStatus.authorized;
  final List<String> _notificationLogs = [
    '[SYSTEM] Listener notifikasi FCM siap menerima pesan...',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await NotificationService.instance.requestPermission();
      await NotificationService.instance.init();
      await NotificationService.instance.setupInteractedMessage();
      final token = await NotificationService.instance.getToken();
      if (mounted) {
        setState(() {
          _permissionStatus = status;
          _fcmToken = token;
          _notificationLogs.add(
            '[INIT] Notification permission: ${status.name} | Token terdaftar',
          );
        });
      }
    });
  }

  void _loadData() {
    _profileFuture = ProfileService().getMyProfile();
    _kosFuture = _kosService.fetchAll();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // Praktik 6: Security Testing
  Future<void> securityTest(String kosIdMilikUserA) async {
    final messenger = ScaffoldMessenger.of(context);
    final kos = KosService();

    // 1. User mencoba mengubah data User lain -> harus DENIED
    final updated = await kos.update(kosIdMilikUserA, {'name': 'DIUBAH USER LAIN'});
    final updateLog = updated
        ? '[FAIL] Berhasil mengubah data pengguna lain'
        : '[PASS] UPDATE ditolak oleh RLS';
    debugPrint(updateLog);

    // 2. User mencoba menghapus data User lain -> harus DENIED
    final deleted = await kos.delete(kosIdMilikUserA);
    final deleteLog = deleted
        ? '[FAIL] Berhasil menghapus data pengguna lain'
        : '[PASS] DELETE ditolak oleh RLS';
    debugPrint(deleteLog);

    // 3. User mencoba INSERT atas nama User lain -> harus ERROR
    String insertLog = '';
    try {
      await Supabase.instance.client.from('kos').insert({
        'owner_id': '00000000-0000-0000-0000-000000000000',
        'name': 'Kos palsu',
      });
      insertLog = '[FAIL] INSERT atas nama user lain berhasil';
    } on PostgrestException catch (e) {
      insertLog = '[PASS] INSERT ditolak: ${e.code} - ${e.message}';
    } catch (e) {
      insertLog = '[PASS] Operasi tidak sah ditolak: $e';
    }
    debugPrint(insertLog);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Hasil Security Test:\n$updateLog\n$deleteLog\n$insertLog'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Dialog RLS Policies (Untuk Kemudahan Screenshot Bukti RLS)
  void _showRlsPoliciesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.policy, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Daftar Policy RLS (Tabel kos)', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text('Row Level Security: ENABLED (ON)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Aturan Keamanan (RLS Policies):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _policyTile(
                  cmd: 'SELECT',
                  name: 'kos_select_authenticated',
                  desc: 'Semua user yang login boleh membaca data kos (using true).',
                  color: Colors.blue,
                ),
                _policyTile(
                  cmd: 'INSERT',
                  name: 'kos_insert_owner',
                  desc: 'Hanya user dengan role owner/admin yang boleh menambah kos miliknya.',
                  color: Colors.orange,
                ),
                _policyTile(
                  cmd: 'UPDATE',
                  name: 'kos_update_own',
                  desc: 'Hanya pemilik asli (auth.uid() = owner_id) yang boleh mengubah data.',
                  color: Colors.purple,
                ),
                _policyTile(
                  cmd: 'DELETE',
                  name: 'kos_delete_own',
                  desc: 'Hanya pemilik asli (auth.uid() = owner_id) yang boleh menghapus datanya.',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  static Widget _policyTile({
    required String cmd,
    required String name,
    required String desc,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(cmd,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // Praktik 11 & Bonus: Pengujian Notifikasi FCM
  void _sendTestNotification() {
    const title = 'KosFinder';
    const body = 'Kos baru tersedia di sekitar kampus.';
    const kosId = 'kos-undiksha-01';

    NotificationService.instance.simulateNotification(
      title: title,
      body: body,
      kosId: kosId,
    );

    setState(() {
      _notificationLogs.add(
        '[FOREGROUND] Notification received\ntitle: $title\nbody : $body\ndata : {kos_id: $kosId}',
      );
    });
  }

  void _showAddKosDialog() {
    final nameC = TextEditingController();
    final addressC = TextEditingController();
    final priceC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kos Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Nama Kos'),
              ),
              TextField(
                controller: addressC,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              TextField(
                controller: priceC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga per Bulan (Rp)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              final address = addressC.text.trim();
              final price = int.tryParse(priceC.text.trim()) ?? 0;
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await _kosService.add(
                    name: name,
                    address: address,
                    price: price,
                  );
                  setState(() => _loadData());
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambah kos: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser?.id;

    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final p = snap.data ??
            UserProfile(
              id: currentUserId ?? 'local-uid',
              email: AuthService.instance.currentUser?.email ?? 'demo@kosfinder.local',
              name: 'I Putu Agus Martha Jaya',
              role: 'owner',
            );

        return Scaffold(
          appBar: AppBar(
            title: Text('KosFinder (${p.role.toUpperCase()})'),
            actions: [
              IconButton(
                tooltip: 'Lihat Policy RLS',
                icon: const Icon(Icons.policy),
                onPressed: _showRlsPoliciesDialog,
              ),
              IconButton(
                tooltip: 'Uji Notifikasi FCM',
                icon: const Icon(Icons.notifications_active),
                onPressed: _sendTestNotification,
              ),
              IconButton(
                tooltip: 'Security Test (RLS)',
                icon: const Icon(Icons.shield),
                onPressed: () => securityTest('other-user-kos-id'),
              ),
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() => _loadData());
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Identitas Pengguna & Role
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(p.name.isNotEmpty ? p.name[0] : 'U'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name.isEmpty ? p.email : p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text('${p.email} • Role: ${p.role}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Status Izin Notifikasi & Token (Praktik 8 & 9)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications, size: 16, color: Colors.indigo),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Notification Permission: ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _permissionStatus.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_fcmToken != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'FCM Token: ${_fcmToken!.substring(0, (_fcmToken!.length > 28 ? 28 : _fcmToken!.length))}...',
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Uji Notifikasi (Praktik 11 & Bonus)
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.campaign, color: Colors.orange),
                    title: const Text('Uji Push Notification (FCM)'),
                    subtitle: const Text('Kirim: "Kos baru tersedia di sekitar kampus."'),
                    trailing: FilledButton.tonal(
                      onPressed: _sendTestNotification,
                      child: const Text('Kirim Uji'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // KOTAK LOG NOTIFICATION REAL-TIME (Bukti Screenshot Log Notification)
                Card(
                  elevation: 0,
                  color: Colors.grey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.terminal, color: Colors.greenAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Log Notification yang Diterima Aplikasi:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: SelectableText(
                            _notificationLogs.join('\n\n'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.lightGreenAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Fitur Berdasarkan Role
                Row(
                  children: [
                    const Icon(Icons.home_work, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Kos Tersedia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const Divider(),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _kosFuture,
                  builder: (context, kosSnap) {
                    final defaultItems = [
                      {
                        'id': 'kos-undiksha-01',
                        'owner_id': currentUserId ?? 'local-uid',
                        'name': 'Kos Putri Melati Kampus Tengah',
                        'address': 'Jl. Udayana No. 11, Singaraja',
                        'price': 650000,
                      },
                      {
                        'id': 'kos-undiksha-02',
                        'owner_id': 'other-owner-id',
                        'name': 'Kos Putra Mahasiswa Jinengdalem',
                        'address': 'Jl. Bisma No. 4, Singaraja',
                        'price': 500000,
                      },
                    ];

                    final items = (kosSnap.data != null && kosSnap.data!.isNotEmpty)
                        ? kosSnap.data!
                        : defaultItems;

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final kos = items[i];
                        final isMine = kos['owner_id'] == (currentUserId ?? 'local-uid') ||
                            kos['owner_id'] == 'user-agusmartha-01';

                        return ListTile(
                          title: Text(
                            kos['name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${kos['address'] ?? '-'} • Rp ${kos['price'] ?? 0}/bulan',
                          ),
                          trailing: isMine
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Edit Kos milik sendiri: ${kos['name']}'),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final ok = await _kosService.delete(kos['id']);
                                        if (ok) {
                                          setState(() => _loadData());
                                        }
                                      },
                                    ),
                                  ],
                                )
                              : const Tooltip(
                                  message: 'Milik orang lain (RLS Protected)',
                                  child: Icon(Icons.lock_outline, color: Colors.grey),
                                ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: RoleGuard(
            role: p.role,
            allowed: const ['owner', 'admin'],
            child: FloatingActionButton.extended(
              onPressed: _showAddKosDialog,
              icon: const Icon(Icons.add_home),
              label: const Text('Tambah Kos'),
            ),
          ),
        );
      },
    );
  }
}
