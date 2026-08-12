import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/phone_number.dart';
import 'profile_service.dart';

// OTP SMS disabilitato: non usato da AuthScreen. Conservato per riattivarlo più avanti.

class PendingRegistration {
  final String email;
  final String password;
  final String nome;
  final String cognome;
  final String telefono;
  final String codiceFiscale;
  final String tipoAttivita;

  const PendingRegistration({
    required this.email,
    required this.password,
    required this.nome,
    required this.cognome,
    required this.telefono,
    required this.codiceFiscale,
    required this.tipoAttivita,
  });

  Map<String, dynamic> get userMetadata => {
        'nome': nome,
        'cognome': cognome,
        'telefono': telefono,
        'codice_fiscale': codiceFiscale,
        'tipo_attivita': tipoAttivita,
      };
}

enum RegistrationOtpMode { sms, local }

class SendRegistrationOtpResult {
  final String phone;
  final RegistrationOtpMode mode;

  const SendRegistrationOtpResult({
    required this.phone,
    required this.mode,
  });
}

/// OTP solo in registrazione: l'account viene creato solo dopo il codice corretto.
class PhoneAuthService {
  PhoneAuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Codice di sviluppo da .env (es. 123456). Se assente e SMS non configurato, l'invio fallisce.
  String? get _devCode {
    final code = dotenv.env['PHONE_OTP_DEV_CODE']?.trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  bool get hasDevOtpFallback => _devCode != null;

  /// Memoria locale del codice in modalità sviluppo (nessun utente su DB finché non verifica).
  final Map<String, _LocalOtp> _localOtps = {};

  Future<SendRegistrationOtpResult> sendRegistrationOtp(String rawPhone) async {
    final phone = PhoneNumber.normalize(rawPhone);
    if (phone == null) {
      throw StateError('Numero di telefono non valido');
    }

    try {
      await _client.auth.signInWithOtp(phone: phone);
      _localOtps.remove(phone);
      return SendRegistrationOtpResult(phone: phone, mode: RegistrationOtpMode.sms);
    } catch (e) {
      if (!_isMissingSmsProvider(e) || !hasDevOtpFallback) {
        rethrow;
      }
    }

    final code = _devCode!;
    _localOtps[phone] = _LocalOtp(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    return SendRegistrationOtpResult(phone: phone, mode: RegistrationOtpMode.local);
  }

  /// Verifica OTP e solo allora crea l'account su Supabase.
  Future<AuthResponse?> verifyAndRegister({
    required PendingRegistration pending,
    required String token,
  }) async {
    final phone = PhoneNumber.normalize(pending.telefono);
    if (phone == null) {
      throw StateError('Numero di telefono non valido');
    }
    final code = token.trim();
    if (code.length < 4) {
      throw StateError('Inserisci il codice ricevuto');
    }

    final local = _localOtps[phone];
    if (local != null) {
      if (DateTime.now().isAfter(local.expiresAt)) {
        _localOtps.remove(phone);
        throw StateError('Codice scaduto. Torna indietro e richiedine uno nuovo.');
      }
      if (code != local.code) {
        throw StateError('Codice non valido');
      }
      _localOtps.remove(phone);
      return _createEmailAccount(pending);
    }

    await _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );

    await _client.auth.updateUser(
      UserAttributes(
        email: pending.email,
        password: pending.password,
        data: pending.userMetadata,
      ),
    );

    await ProfileService().saveIdentityFields(
      nome: pending.nome,
      cognome: pending.cognome,
      telefono: phone,
      codiceFiscale: pending.codiceFiscale,
      tipoAttivita: pending.tipoAttivita,
    );
    return null;
  }

  Future<AuthResponse> _createEmailAccount(PendingRegistration pending) async {
    final response = await _client.auth.signUp(
      email: pending.email,
      password: pending.password,
      data: pending.userMetadata,
    );

    if (response.session != null) {
      await ProfileService().saveIdentityFields(
        nome: pending.nome,
        cognome: pending.cognome,
        telefono: pending.telefono,
        codiceFiscale: pending.codiceFiscale,
        tipoAttivita: pending.tipoAttivita,
      );
    }
    return response;
  }

  bool _isMissingSmsProvider(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('unable to get sms provider') ||
        text.contains('sms provider') ||
        text.contains('unsupported phone provider') ||
        text.contains('phone provider') ||
        (error is AuthException && (error.code == 'unexpected_failure' || text.contains('unexpected_failure')));
  }

  String friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (_isMissingSmsProvider(error)) {
      return 'SMS non configurato su Supabase. Abilita Authentication → Phone (Twilio) '
          'oppure imposta PHONE_OTP_DEV_CODE in .env per lo sviluppo.';
    }
    if (text.contains('rate limit') || text.contains('over_sms_send_rate_limit')) {
      return 'Troppi tentativi. Attendi un minuto e riprova.';
    }
    if (text.contains('invalid') && (text.contains('otp') || text.contains('token') || text.contains('codice'))) {
      return 'Codice non valido o scaduto.';
    }
    if (text.contains('already registered') || text.contains('user already')) {
      return 'Email o telefono già registrati.';
    }
    if (error is AuthException) return error.message;
    if (error is StateError) return error.message;
    return 'Impossibile completare la verifica. Riprova.';
  }
}

class _LocalOtp {
  final String code;
  final DateTime expiresAt;

  _LocalOtp({required this.code, required this.expiresAt});
}
