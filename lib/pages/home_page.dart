import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/kos_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
        final p = snap.data;
        if (snap.hasError || p == null) {
          return const Scaffold(
            body: Center(child: Text('Gagal memuat profil')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('KosFinder (${p.role})'),
            actions: [
              IconButton(
                tooltip: 'Security Test',
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
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(
                      p.name.isEmpty ? p.email : p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${p.email} • Role: ${p.role.toUpperCase()}'),
                  ),
                ),
                const SizedBox(height: 12),
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
                    if (kosSnap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final items = kosSnap.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Belum ada data kos tersedia.'),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final kos = items[i];
                        final isMine = kos['owner_id'] == currentUserId;

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
                                        // Edit kos
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
                              : null,
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
