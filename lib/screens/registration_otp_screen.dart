import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/phone_auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/phone_number.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_fields.dart';

// OTP SMS disabilitato: non collegato ad AuthScreen. Conservato per riattivarlo più avanti.

/// Step post-form registrazione: OTP prima di salvare l'account sul database.
class RegistrationOtpScreen extends StatefulWidget {
  final PendingRegistration pending;

  const RegistrationOtpScreen({super.key, required this.pending});

  @override
  State<RegistrationOtpScreen> createState() => _RegistrationOtpScreenState();
}

class _RegistrationOtpScreenState extends State<RegistrationOtpScreen> {
  final _phoneService = PhoneAuthService();
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _sending = true;
  String? _error;
  String? _info;
  RegistrationOtpMode? _mode;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  String get _phone => widget.pending.telefono;
  String get _phoneDisplay => PhoneNumber.display(_phone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final result = await _phoneService.sendRegistrationOtp(_phone);
      if (!mounted) return;
      setState(() {
        _mode = result.mode;
        _info = result.mode == RegistrationOtpMode.local
            ? 'Modalità sviluppo: inserisci il codice di test configurato in .env'
            : null;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _phoneService.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _sending = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'Inserisci il codice OTP');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _phoneService.verifyAndRegister(
        pending: widget.pending,
        token: _otpCtrl.text,
      );
      if (!mounted) return;

      // Se non c'è sessione (conferma email richiesta), torna al login con messaggio.
      // Se c'è sessione, AppBootstrap sostituisce l'albero e porta all'app.
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        Navigator.of(context).pop(
          'Registrazione completata. Controlla la casella email e conferma l\'account, poi accedi.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _phoneService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Torna indietro'),
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: AppLogo(size: 64, borderRadius: 16)),
            const SizedBox(height: 12),
            const Text(
              'MUD',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica telefono',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 16),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _sending
                    ? 'Invio del codice in corso a $_phoneDisplay…'
                    : 'È stato inviato un codice OTP al numero $_phoneDisplay. '
                        'Inseriscilo qui sotto per completare la registrazione.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 28),
            formLabel('Codice OTP'),
            TextField(
              controller: _otpCtrl,
              enabled: !_loading && !_sending,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading || _sending ? null : _confirm(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6),
              decoration: InputDecoration(
                hintText: 'codice otp',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: AppColors.textLightGrey,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Numero errato? Torna indietro e correggilo nel form di registrazione.',
              style: TextStyle(color: AppColors.textLightGrey.withValues(alpha: 0.95), fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 16),
              Text(_info!, style: const TextStyle(color: AppColors.green)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _sending) ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Conferma e registra',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: (_loading || _sending || _resendSeconds > 0) ? null : _sendOtp,
              child: Text(
                _resendSeconds > 0 ? 'Reinvia codice tra $_resendSeconds s' : 'Reinvia codice',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_mode == RegistrationOtpMode.local) ...[
              const SizedBox(height: 8),
              const Text(
                'SMS provider non attivo: stai usando il codice di sviluppo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
