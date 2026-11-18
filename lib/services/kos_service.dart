import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class KosService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _uid =>
      AuthService.instance.currentUser?.id ??
      _client.auth.currentUser?.id ??
      'user-agusmartha-01';

  // In-memory list untuk demo jika Supabase offline/dummy
  static final List<Map<String, dynamic>> _demoList = [
    {
      'id': 'kos-undiksha-01',
      'owner_id': 'user-agusmartha-01',
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

  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      final data = await _client
          .from('kos')
          .select()
          .order('created_at', ascending: false);
      if (data.isNotEmpty) {
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (_) {}
    return List<Map<String, dynamic>>.from(_demoList);
  }

  Future<void> add({
    required String name,
    required String address,
    required int price,
  }) async {
    try {
      await _client.from('kos').insert({
        'owner_id': _uid,
        'name': name,
        'address': address,
        'price': price,
      });
    } catch (_) {
      // Demo/local fallback: tambahkan ke list lokal jika backend Supabase belum diisi
      _demoList.insert(0, {
        'id': 'kos-${DateTime.now().millisecondsSinceEpoch}',
        'owner_id': _uid,
        'name': name,
        'address': address,
        'price': price,
      });
    }
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> update(String id, Map<String, dynamic> values) async {
    try {
      final rows =
          await _client.from('kos').update(values).eq('id', id).select();
      if (rows.isNotEmpty) return true;
    } catch (_) {}

    // Demo check: tolak jika bukan milik _uid
    final item = _demoList.firstWhere((k) => k['id'] == id, orElse: () => {});
    if (item.isNotEmpty && item['owner_id'] == _uid) {
      item.addAll(values);
      return true;
    }
    return false; // ditolak RLS
  }

  /// true = berhasil, false = ditolak RLS / data tidak ditemukan
  Future<bool> delete(String id) async {
    try {
      final rows = await _client.from('kos').delete().eq('id', id).select();
      if (rows.isNotEmpty) return true;
    } catch (_) {}

    // Demo check: tolak jika bukan milik _uid
    final index = _demoList.indexWhere((k) => k['id'] == id);
    if (index != -1 && _demoList[index]['owner_id'] == _uid) {
      _demoList.removeAt(index);
      return true;
    }
    return false; // ditolak RLS
  }
}
