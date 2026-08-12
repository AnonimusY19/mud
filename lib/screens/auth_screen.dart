import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/profile_service.dart';
import '../utils/codice_fiscale.dart';
import '../widgets/form_fields.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _codiceFiscaleCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _telefonoCtrl.dispose();
    _codiceFiscaleCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('email not confirmed') || text.contains('email_not_confirmed')) {
      return 'Email non confermata. Apri il link che ti abbiamo inviato, poi riprova ad accedere.';
    }
    if (text.contains('connection refused') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception')) {
      return 'Impossibile contattare Supabase. Controlla SUPABASE_URL in .env e riavvia l\'app.';
    }
    if (error is AuthException) {
      if (error.message.toLowerCase().contains('email not confirmed')) {
        return 'Email non confermata. Apri il link che ti abbiamo inviato, poi riprova ad accedere.';
      }
      return error.message;
    }
    return 'Errore di autenticazione. Riprova.';
  }

  bool _validateRegistration() {
    if (_nomeCtrl.text.trim().isEmpty ||
        _cognomeCtrl.text.trim().isEmpty ||
        _telefonoCtrl.text.trim().isEmpty ||
        _codiceFiscaleCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Compila nome, cognome, telefono e codice fiscale';
        _info = null;
      });
      return false;
    }

    final cfError = CodiceFiscale.validate(_codiceFiscaleCtrl.text);
    if (cfError != null) {
      setState(() {
        _error = cfError;
        _info = null;
      });
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Inserisci email e password';
        _info = null;
      });
      return;
    }

    if (!_isLogin && !_validateRegistration()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_isLogin) {
        await auth.signInWithPassword(email: email, password: password);
      } else {
        final nome = _nomeCtrl.text.trim();
        final cognome = _cognomeCtrl.text.trim();
        final telefono = _telefonoCtrl.text.trim();
        final codiceFiscale = _codiceFiscaleCtrl.text.trim().toUpperCase();

        final response = await auth.signUp(
          email: email,
          password: password,
          data: {
            'nome': nome,
            'cognome': cognome,
            'telefono': telefono,
            'codice_fiscale': codiceFiscale,
          },
        );

        // Se la sessione c'è subito, scriviamo anche sulla tabella profiles
        if (response.session != null) {
          await ProfileService().saveIdentityFields(
            nome: nome,
            cognome: cognome,
            telefono: telefono,
            codiceFiscale: codiceFiscale,
          );
        }

        if (!mounted) return;
        if (response.session == null) {
          setState(() {
            _isLogin = true;
            _info = 'Registrazione riuscita. Controlla la casella email e conferma l\'account, poi accedi.';
          });
        }
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            const Text(
              'MUD',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin ? 'Accedi al tuo account' : 'Crea un nuovo account',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            if (!_isLogin) ...[
              formLabel('Nome'),
              formTextField(controller: _nomeCtrl, hint: 'Mario'),
              const SizedBox(height: 20),
              formLabel('Cognome'),
              formTextField(controller: _cognomeCtrl, hint: 'Rossi'),
              const SizedBox(height: 20),
              formLabel('Telefono'),
              formTextField(controller: _telefonoCtrl, hint: '+39...', keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              formLabel('Codice fiscale'),
              formTextField(controller: _codiceFiscaleCtrl, hint: 'RSSMRA80A01H501U'),
              const SizedBox(height: 20),
            ],
            formLabel('Email'),
            formTextField(controller: _emailCtrl, hint: 'nome@azienda.it', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            formLabel('Password'),
            formTextField(
              controller: _passwordCtrl,
              hint: 'Minimo 6 caratteri',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textGrey,
                ),
              ),
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
                onPressed: _loading ? null : _submit,
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
                    : Text(
                        _isLogin ? 'Accedi' : 'Registrati',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                        _info = null;
                      }),
              child: Text(
                _isLogin ? 'Non hai un account? Registrati' : 'Hai già un account? Accedi',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
