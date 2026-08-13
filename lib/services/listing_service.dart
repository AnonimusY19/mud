import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';

class ListingService {
  ListingService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Listing>> fetchAll() async {
    final rows = await _client.from('listings').select().order('created_at', ascending: false);
    final listings = (rows as List)
        .map((row) => Listing.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();

    final userIds = listings.map((l) => l.userId).toSet().toList();
    final companies = await _loadCompanyNames(userIds);

    return [
      for (final listing in listings) listing.copyWith(companyName: companies[listing.userId] ?? ''),
    ];
  }

  /// Carica id → nome_azienda. Usa RPC security definer; fallback su select profiles.
  Future<Map<String, String>> _loadCompanyNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      final rows = await _client.rpc('marketplace_company_names');
      return {
        for (final row in (rows as List))
          (row as Map)['id'].toString(): (row['nome_azienda'] as String?)?.trim() ?? '',
      };
    } catch (_) {
      // RPC non ancora applicata: prova select diretto (serve policy marketplace).
    }

    try {
      final profileRows = await _client
          .from('profiles')
          .select('id, nome_azienda')
          .inFilter('id', userIds);
      return {
        for (final row in (profileRows as List))
          (row as Map)['id'].toString(): (row['nome_azienda'] as String?)?.trim() ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  Future<Listing> create(Listing listing) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Utente non autenticato');

    final data = await _client.from('listings').insert(listing.toInsertJson(userId)).select().single();
    final created = Listing.fromJson(data);
    final profile = await _client.from('profiles').select('nome_azienda').eq('id', userId).maybeSingle();
    return created.copyWith(companyName: (profile?['nome_azienda'] as String?) ?? '');
  }

  Future<Listing> update(Listing listing) async {
    final data = await _client.from('listings').update(listing.toUpdateJson()).eq('id', listing.id).select().single();
    return Listing.fromJson(data).copyWith(companyName: listing.companyName);
  }

  Future<void> delete(String id) async {
    await _client.from('listings').delete().eq('id', id);
  }
}
