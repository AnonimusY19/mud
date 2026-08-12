import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';

class ListingService {
  ListingService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Listing>> fetchAll() async {
    final rows = await _client.from('listings').select().order('created_at', ascending: false);
    return (rows as List).map((row) => Listing.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<Listing> create(Listing listing) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Utente non autenticato');

    final data = await _client.from('listings').insert(listing.toInsertJson(userId)).select().single();
    return Listing.fromJson(data);
  }

  Future<Listing> update(Listing listing) async {
    final data = await _client.from('listings').update(listing.toUpdateJson()).eq('id', listing.id).select().single();
    return Listing.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('listings').delete().eq('id', id);
  }
}
