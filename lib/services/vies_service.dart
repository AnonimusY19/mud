import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/partita_iva.dart';

/// Esito verifica VIES (via Supabase Edge Function `verify-vat`).
sealed class ViesResult {
  const ViesResult();
}

class ViesValid extends ViesResult {
  final String? name;
  final String? address;
  final String vatNumber;
  final String verificationId;

  const ViesValid({
    required this.vatNumber,
    required this.verificationId,
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

/// Client Flutter → Edge Function `verify-vat` → VIES UE.
class ViesService {
  ViesService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ViesResult> checkItalianVat(String raw) async {
    final formatError = PartitaIva.validate(raw);
    if (formatError != null) {
      return ViesInvalid(formatError);
    }

    final vatNumber = PartitaIva.normalize(raw);

    try {
      final response = await _client.functions.invoke(
        'verify-vat',
        body: {
          'partitaIva': vatNumber,
          'countryCode': 'IT',
        },
      );

      final data = response.data;
      if (data is! Map) {
        return const ViesUnavailable('Risposta del server non valida. Riprova.');
      }

      final map = Map<String, dynamic>.from(data);
      final status = (map['status'] as String?)?.toLowerCase() ?? '';
      final message = (map['message'] as String?)?.trim();

      switch (status) {
        case 'valid':
          final verificationId = (map['verificationId'] as String?)?.trim() ?? '';
          if (verificationId.isEmpty) {
            return const ViesUnavailable(
              'Verifica VIES incompleta (manca verificationId). Aggiorna la Edge Function.',
            );
          }
          return ViesValid(
            vatNumber: (map['vatNumber'] as String?)?.trim().isNotEmpty == true
                ? (map['vatNumber'] as String).trim()
                : vatNumber,
            verificationId: verificationId,
            name: (map['name'] as String?)?.trim(),
            address: (map['address'] as String?)?.trim(),
          );
        case 'invalid':
          return ViesInvalid(
            message?.isNotEmpty == true
                ? message!
                : 'Partita IVA non attiva o non presente in VIES',
          );
        case 'unavailable':
        case 'error':
          return ViesUnavailable(
            message?.isNotEmpty == true
                ? message!
                : 'Servizio VIES non disponibile. Riprova tra poco.',
          );
        default:
          return const ViesUnavailable(
            'Risposta VIES non riconosciuta. Riprova.',
          );
      }
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['message'] != null) {
        return ViesUnavailable(details['message'].toString());
      }
      if (e.status == 404) {
        return const ViesUnavailable(
          'Funzione verify-vat non trovata. Esegui: npx supabase functions deploy verify-vat',
        );
      }
      if (e.status == 429) {
        return const ViesUnavailable(
          'Troppe verifiche VIES. Riprova tra qualche minuto.',
        );
      }
      return ViesUnavailable(
        'Verifica VIES non riuscita (HTTP ${e.status}). Riprova.',
      );
    } catch (_) {
      return const ViesUnavailable(
        'Impossibile contattare il server per la verifica VIES. Riprova.',
      );
    }
  }
}
