import 'dart:convert';

import 'package:http/http.dart' as http;
import '../utils/partita_iva.dart';

/// Esito verifica VIES (VAT Information Exchange System).
sealed class ViesResult {
  const ViesResult();
}

class ViesValid extends ViesResult {
  final String? name;
  final String? address;
  final String vatNumber;

  const ViesValid({
    required this.vatNumber,
    this.name,
    this.address,
  });
}

class ViesInvalid extends ViesResult {
  final String message;
  const ViesInvalid(this.message);
}

class ViesUnavailable extends ViesResult {
  final String message;
  const ViesUnavailable(this.message);
}

/// Client REST ufficiale VIES (Commissione Europea).
class ViesService {
  ViesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _uri = Uri.parse(
    'https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number',
  );

  /// Verifica una Partita IVA italiana su VIES.
  /// Prima applica la validazione formale locale, poi interroga VIES.
  Future<ViesResult> checkItalianVat(String raw) async {
    final formatError = PartitaIva.validate(raw);
    if (formatError != null) {
      return ViesInvalid(formatError);
    }

    final vatNumber = PartitaIva.normalize(raw);

    try {
      final response = await _client
          .post(
            _uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'countryCode': 'IT',
              'vatNumber': vatNumber,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 400) {
        return const ViesInvalid('Partita IVA non riconosciuta da VIES');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ViesUnavailable(
          'Servizio VIES non disponibile (HTTP ${response.statusCode}). Riprova tra poco.',
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return const ViesUnavailable('Risposta VIES non valida. Riprova.');
      }

      final map = Map<String, dynamic>.from(data);
      final userError = (map['userError'] as String?)?.trim();
      if (userError != null &&
          userError.isNotEmpty &&
          userError.toUpperCase() != 'VALID' &&
          userError.toUpperCase() != 'NONE') {
        // MS_UNAVAILABLE, TIMEOUT, ecc.
        if (userError.toUpperCase().contains('UNAVAILABLE') ||
            userError.toUpperCase().contains('TIMEOUT') ||
            userError.toUpperCase().contains('MS_MAX')) {
          return ViesUnavailable(
            'Archivio IVA italiano temporaneamente non raggiungibile via VIES. Riprova tra poco.',
          );
        }
        return ViesInvalid('Partita IVA non valida secondo VIES ($userError)');
      }

      final valid = map['valid'] == true || map['isValid'] == true;
      if (!valid) {
        return const ViesInvalid(
          'Partita IVA non attiva o non presente in VIES',
        );
      }

      final name = (map['name'] as String?)?.trim();
      final address = (map['address'] as String?)?.trim();
      return ViesValid(
        vatNumber: vatNumber,
        name: (name == null || name == '---') ? null : name,
        address: (address == null || address == '---') ? null : address,
      );
    } on http.ClientException {
      return const ViesUnavailable(
        'Impossibile contattare VIES. Controlla la connessione e riprova.',
      );
    } catch (_) {
      return const ViesUnavailable(
        'Verifica VIES non riuscita. Controlla la connessione e riprova.',
      );
    }
  }
}
