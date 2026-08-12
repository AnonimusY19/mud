import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../models/listing.dart';
import '../models/profile.dart';
import '../utils/stream_token.dart';

/// Client Stream Chat condiviso (1:1 per annuncio).
class StreamChatService {
  StreamChatService._();
  static final StreamChatService instance = StreamChatService._();

  StreamChatClient? _client;
  bool _connecting = false;

  StreamChatClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('Stream Chat non inizializzato. Controlla STREAM_API_KEY in .env');
    }
    return c;
  }

  bool get isReady => _client != null && _client!.state.currentUser != null;

  String? get _apiKey => dotenv.env['STREAM_API_KEY']?.trim();
  String? get _apiSecret => dotenv.env['STREAM_API_SECRET']?.trim();

  bool get isConfigured {
    final key = _apiKey;
    final secret = _apiSecret;
    return key != null &&
        key.isNotEmpty &&
        key != 'your-stream-api-key' &&
        secret != null &&
        secret.isNotEmpty &&
        secret != 'your-stream-api-secret';
  }

  Future<void> connect(Profile profile) async {
    if (!isConfigured) {
      debugPrint('Stream Chat: STREAM_API_KEY / STREAM_API_SECRET non configurati');
      return;
    }
    if (_connecting) return;
    if (_client?.state.currentUser?.id == profile.id) return;

    _connecting = true;
    try {
      await disconnect();

      final apiKey = _apiKey!;
      final apiSecret = _apiSecret!;
      _client = StreamChatClient(apiKey, logLevel: Level.WARNING);

      final displayName = [
        if (profile.nomeAzienda.trim().isNotEmpty) profile.nomeAzienda.trim(),
        if (profile.nome.trim().isNotEmpty || profile.cognome.trim().isNotEmpty)
          '${profile.nome} ${profile.cognome}'.trim(),
      ].where((e) => e.isNotEmpty).join(' · ');

      final token = createStreamUserToken(userId: profile.id, apiSecret: apiSecret);
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
      throw StateError('Chat non disponibile. Configura Stream e riprova ad accedere.');
    }
    if (listing.userId == currentUserId) {
      throw StateError('Non puoi contattare il tuo stesso annuncio.');
    }

    final otherName = listing.companyName.trim().isNotEmpty
        ? listing.companyName.trim()
        : 'Venditore';

    // Stream richiede che entrambi gli utenti esistano prima di creare il canale.
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
        'name': listing.title,
        'listing_id': listing.id,
        'listing_title': listing.title,
        'listing_company': otherName,
        'image': listing.imageUrl,
      },
    );

    await channel.watch();
    return channel;
  }

  /// Crea/aggiorna un utente su Stream (server JWT) se non ha mai fatto login chat.
  Future<void> _ensureStreamUser({
    required String userId,
    required String name,
    String? image,
  }) async {
    final apiKey = _apiKey;
    final apiSecret = _apiSecret;
    if (apiKey == null || apiSecret == null) {
      throw StateError('Stream non configurato');
    }

    final token = createStreamServerToken(apiSecret: apiSecret);
    final uri = Uri.parse(
      'https://chat.stream-io-api.com/users?api_key=$apiKey',
    );
    final body = {
      'users': {
        userId: {
          'id': userId,
          'name': name,
          if (image != null && image.isNotEmpty) 'image': image,
        },
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
        'Stream-Auth-Type': 'jwt',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Stream upsert user failed: ${response.statusCode} ${response.body}');
      throw StateError('Impossibile preparare la chat con il venditore.');
    }
  }

  /// ID canale stabile e <= 64 caratteri (limite Stream).
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
