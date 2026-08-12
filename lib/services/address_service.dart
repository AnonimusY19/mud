import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/address.dart';

/// Service Google Places API (New): Autocomplete + Place Details con session token.
class AddressService {
  AddressService({
    http.Client? client,
    this.languageCode = 'it',
    this.regionCode = 'IT',
    this.includedRegionCodes = const [],
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String languageCode;
  final String regionCode;

  /// Se non vuoto, limita i risultati a questi paesi (es. `['it']`).
  /// Lascia vuoto per ricerche globali; `regionCode` dà comunque priorità all'Italia.
  final List<String> includedRegionCodes;

  static const _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  static const _maxSuggestions = 7;

  String? _sessionToken;

  String get _apiKey {
    final key = dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';
    if (key.isEmpty || key == 'your-google-places-api-key') {
      throw StateError(
        'Configura GOOGLE_PLACES_API_KEY in .env (Google Cloud → Places API New).',
      );
    }
    return key;
  }

  String _ensureSessionToken() {
    return _sessionToken ??= _generateSessionToken();
  }

  void _refreshSessionToken() {
    _sessionToken = _generateSessionToken();
  }

  String _generateSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Autocomplete in tempo reale (debounce gestito dal widget).
  Future<List<AddressSuggestion>> autocomplete(String input) async {
    final query = input.trim();
    if (query.length < 2) return const [];

    final body = <String, dynamic>{
      'input': query,
      'languageCode': languageCode,
      'regionCode': regionCode,
      'sessionToken': _ensureSessionToken(),
      if (includedRegionCodes.isNotEmpty) 'includedRegionCodes': includedRegionCodes,
    };

    final response = await _client.post(
      Uri.parse(_autocompleteUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AddressServiceException(
        'Autocomplete fallito (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = decoded['suggestions'] as List<dynamic>? ?? const [];
    final results = <AddressSuggestion>[];

    for (final item in suggestions) {
      final map = item as Map<String, dynamic>;
      final prediction = map['placePrediction'] as Map<String, dynamic>?;
      if (prediction == null) continue;

      final placeId = (prediction['placeId'] as String?) ?? '';
      if (placeId.isEmpty) continue;

      final structured = prediction['structuredFormat'] as Map<String, dynamic>?;
      final main = (structured?['mainText'] as Map<String, dynamic>?)?['text'] as String?;
      final secondary = (structured?['secondaryText'] as Map<String, dynamic>?)?['text'] as String?;
      final full = (prediction['text'] as Map<String, dynamic>?)?['text'] as String?;

      results.add(
        AddressSuggestion(
          placeId: placeId,
          primaryText: (main ?? full ?? '').trim(),
          secondaryText: (secondary ?? '').trim(),
        ),
      );

      if (results.length >= _maxSuggestions) break;
    }

    return results;
  }

  /// Place Details: termina la sessione e genera un nuovo token.
  Future<Address> fetchDetails(String placeId) async {
    final token = _ensureSessionToken();
    final uri = Uri.https(
      'places.googleapis.com',
      '/v1/places/$placeId',
      {'sessionToken': token, 'languageCode': languageCode, 'regionCode': regionCode},
    );

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'id,formattedAddress,addressComponents,location',
      },
    );

    // Sessione conclusa: nuovo token per la prossima ricerca
    _refreshSessionToken();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AddressServiceException(
        'Place Details fallito (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _mapPlaceDetails(decoded, fallbackPlaceId: placeId);
  }

  Address _mapPlaceDetails(Map<String, dynamic> json, {required String fallbackPlaceId}) {
    final components = (json['addressComponents'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    String component(String type, {bool short = false}) {
      for (final c in components) {
        final types = (c['types'] as List<dynamic>? ?? const []).cast<String>();
        if (types.contains(type)) {
          return ((short ? c['shortText'] : c['longText']) as String?)?.trim() ?? '';
        }
      }
      return '';
    }

    final location = json['location'] as Map<String, dynamic>?;
    final city = component('locality').isNotEmpty
        ? component('locality')
        : (component('postal_town').isNotEmpty
            ? component('postal_town')
            : component('administrative_area_level_3'));

    return Address(
      formattedAddress: (json['formattedAddress'] as String?)?.trim() ?? '',
      street: component('route'),
      streetNumber: component('street_number'),
      city: city,
      province: component('administrative_area_level_2', short: true),
      postalCode: component('postal_code'),
      region: component('administrative_area_level_1'),
      country: component('country', short: true),
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      placeId: (json['id'] as String?)?.replaceFirst('places/', '') ?? fallbackPlaceId,
    );
  }
}

class AddressServiceException implements Exception {
  AddressServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
