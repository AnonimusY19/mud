import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/listing.dart';
import '../models/profile.dart';

/// Client Stream Chat condiviso (token e upsert solo via Edge Function).
class StreamChatService {
  StreamChatService._();
  static final StreamChatService instance = StreamChatService._();

  StreamChatClient? _client;
  bool _connecting = false;

  StreamChatClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('Stream Chat non inizializzato');
    }
    return c;
  }

  bool get isReady => _client != null && _client!.state.currentUser != null;

  /// Solo la API key pubblica resta in app; la secret sta sul server.
  bool get isConfigured {
    final key = dotenv.env['STREAM_API_KEY']?.trim();
    return key != null && key.isNotEmpty && key != 'your-stream-api-key';
  }

  Future<Map<String, dynamic>> _invokeStreamToken(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'stream-token',
      body: body,
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('Risposta stream-token non valida');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> connect(Profile profile) async {
    if (!isConfigured) {
      debugPrint('Stream Chat: STREAM_API_KEY non configurata');
      return;
    }
    if (_connecting) return;
    if (_client?.state.currentUser?.id == profile.id) return;

    _connecting = true;
    try {
      await disconnect();

      final displayName = [
        if (profile.nomeAzienda.trim().isNotEmpty) profile.nomeAzienda.trim(),
        if (profile.nome.trim().isNotEmpty || profile.cognome.trim().isNotEmpty)
          '${profile.nome} ${profile.cognome}'.trim(),
      ].where((e) => e.isNotEmpty).join(' · ');

      final payload = await _invokeStreamToken({
        'action': 'token',
        'name': displayName.isNotEmpty ? displayName : profile.id,
        if (profile.logoUrl != null && profile.logoUrl!.isNotEmpty) 'image': profile.logoUrl,
      });

      final apiKey = (payload['apiKey'] as String?)?.trim();
      final token = (payload['token'] as String?)?.trim();
      if (apiKey == null || apiKey.isEmpty || token == null || token.isEmpty) {
        throw StateError('Token Stream non ricevuto dal server');
      }

      _client = StreamChatClient(apiKey, logLevel: Level.WARNING);
      await _client!.connectUser(
        User(
          id: profile.id,
          name: displayName.isNotEmpty ? displayName : profile.id,
          image: profile.logoUrl,
          extraData: {
            'azienda': profile.nomeAzienda,
            'tipo_attivita': profile.tipoAttivita,
          },
        ),
        token,
      );
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    final c = _client;
    if (c == null) return;
    try {
      await c.disconnectUser();
    } catch (_) {}
    await c.dispose();
    _client = null;
  }

  /// Apre (o riusa) una chat 1:1 legata all'annuncio.
  Future<Channel> openListingChat({
    required Listing listing,
    required String currentUserId,
  }) async {
    if (!isReady) {
      throw StateError('Chat non disponibile. Riprova ad accedere.');
    }
    if (listing.userId == currentUserId) {
      throw StateError('Non puoi contattare il tuo stesso annuncio.');
    }

    final otherName = listing.displayCompanyName.trim().isNotEmpty
        ? listing.displayCompanyName.trim()
        : 'Venditore';

    await _ensureStreamUser(
      userId: listing.userId,
      name: otherName,
      image: listing.imageUrl,
    );

    final channelId = _channelIdForListing(
      listingId: listing.id,
      userA: currentUserId,
      userB: listing.userId,
    );

    final channel = client.channel(
      'messaging',
      id: channelId,
      extraData: {
        'members': [currentUserId, listing.userId],
        'name': listing.displayTitle,
        'listing_id': listing.id,
        'listing_title': listing.displayTitle,
        'listing_company': otherName,
        'image': listing.imageUrl,
      },
    );

    await channel.watch();
    return channel;
  }

  Future<void> _ensureStreamUser({
    required String userId,
    required String name,
    String? image,
  }) async {
    final payload = await _invokeStreamToken({
      'action': 'ensure-user',
      'ensureUserId': userId,
      'ensureName': name,
      if (image != null && image.isNotEmpty) 'ensureImage': image,
    });
    if (payload['ok'] != true) {
      throw StateError('Impossibile preparare la chat con il venditore.');
    }
  }

  String _channelIdForListing({
    required String listingId,
    required String userA,
    required String userB,
  }) {
    final users = [userA.replaceAll('-', ''), userB.replaceAll('-', '')]..sort();
    final l = listingId.replaceAll('-', '');
    return 'l_${l.substring(0, 20)}_${users[0].substring(0, 18)}_${users[1].substring(0, 18)}';
  }
}
