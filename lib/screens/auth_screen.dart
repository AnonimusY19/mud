import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/profile_service.dart';
import '../utils/codice_fiscale.dart';
import '../utils/phone_number.dart';
import '../widgets/form_fields.dart';

// OTP SMS disabilitato temporaneamente (manca provider Twilio).
// Per riattivarlo: usare RegistrationOtpScreen + PhoneAuthService al posto del signUp diretto.

class AuthScreen extends StatefulWidget {
  final String? initialMessage;

  const AuthScreen({super.key, this.initialMessage});

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
  final _nomeAziendaCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _tipoAttivita; // 'Fornitore' | 'Acquirente'
  String? _error;
  String? _info;

  /// Split branding|form solo su web/desktop (non Android/iOS).
  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
      default:
        return true;
    }
  }

  bool _useSplitLayout(BuildContext context) {
    if (!_isDesktopOrWeb) return false;
    return MediaQuery.sizeOf(context).width >= 900;
  }

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != oldWidget.initialMessage && widget.initialMessage != null) {
      _error = widget.initialMessage;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _telefonoCtrl.dispose();
    _codiceFiscaleCtrl.dispose();
    _nomeAziendaCtrl.dispose();
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
        _codiceFiscaleCtrl.text.trim().isEmpty ||
        _nomeAziendaCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Compila nome, cognome, telefono, codice fiscale e nome azienda';
        _info = null;
      });
      return false;
    }

    if (_tipoAttivita != 'Fornitore' && _tipoAttivita != 'Acquirente') {
      setState(() {
        _error = 'Scegli se sei un fornitore o un acquirente';
        _info = null;
      });
      return false;
    }

    final phoneError = PhoneNumber.validate(_telefonoCtrl.text);
    if (phoneError != null) {
      setState(() {
        _error = phoneError;
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
        final telefono = PhoneNumber.normalize(_telefonoCtrl.text)!;
        final codiceFiscale = _codiceFiscaleCtrl.text.trim().toUpperCase();
        final nomeAzienda = _nomeAziendaCtrl.text.trim();
        final tipoAttivita = _tipoAttivita!;

        final response = await auth.signUp(
          email: email,
          password: password,
          data: {
            'nome': nome,
            'cognome': cognome,
            'telefono': telefono,
            'codice_fiscale': codiceFiscale,
            'nome_azienda': nomeAzienda,
            'tipo_attivita': tipoAttivita,
          },
        );

        if (response.session != null) {
          await ProfileService().saveIdentityFields(
            nome: nome,
            cognome: cognome,
            telefono: telefono,
            codiceFiscale: codiceFiscale,
            nomeAzienda: nomeAzienda,
            tipoAttivita: tipoAttivita,
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

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_useSplitLayout(context)) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(flex: 5, child: _BrandingPane(isLogin: _isLogin)),
            Expanded(
              flex: 6,
              child: ColoredBox(
                color: const Color(0xFF0B1B33),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480, maxHeight: 820),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _FormPane(
                          isLogin: _isLogin,
                          loading: _loading,
                          obscurePassword: _obscurePassword,
                          error: _error,
                          info: _info,
                          tipoAttivita: _tipoAttivita,
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          nomeCtrl: _nomeCtrl,
                          cognomeCtrl: _cognomeCtrl,
                          telefonoCtrl: _telefonoCtrl,
                          codiceFiscaleCtrl: _codiceFiscaleCtrl,
                          nomeAziendaCtrl: _nomeAziendaCtrl,
                          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                          onTipoChanged: (v) => setState(() => _tipoAttivita = v),
                          onSubmit: _submit,
                          onToggleMode: _toggleMode,
                          padded: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Android / iOS (e finestre strette): layout originale a colonna unica
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _FormPane(
          isLogin: _isLogin,
          loading: _loading,
          obscurePassword: _obscurePassword,
          error: _error,
          info: _info,
          tipoAttivita: _tipoAttivita,
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          nomeCtrl: _nomeCtrl,
          cognomeCtrl: _cognomeCtrl,
          telefonoCtrl: _telefonoCtrl,
          codiceFiscaleCtrl: _codiceFiscaleCtrl,
          nomeAziendaCtrl: _nomeAziendaCtrl,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          onTipoChanged: (v) => setState(() => _tipoAttivita = v),
          onSubmit: _submit,
          onToggleMode: _toggleMode,
          padded: true,
          showMobileHeader: true,
        ),
      ),
    );
  }
}

class _BrandingPane extends StatelessWidget {
  final bool isLogin;
  const _BrandingPane({required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A1628),
            Color(0xFF0E4FC4),
            Color(0xFF1266F1),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 48, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.hub_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'MUD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                isLogin ? 'Bentornato sul marketplace B2B' : 'Entra nel marketplace B2B',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'MUD connette aziende che vendono e cercano materiali, macchinari e servizi. '
                'Pubblica annunci, trova fornitori e acquirenti, e avvia trattative in un unico posto.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 28),
              const _BrandBullet(text: 'Annunci di vendita e ricerca tra imprese'),
              const SizedBox(height: 12),
              const _BrandBullet(text: 'Profili aziendali e contatti diretti'),
              const SizedBox(height: 12),
              const _BrandBullet(text: 'Marketplace pensato per fornitori e acquirenti'),
              const Spacer(),
              Text(
                'Marketplace per lo scambio tra imprese',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBullet extends StatelessWidget {
  final String text;
  const _BrandBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF93C5FD), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormPane extends StatelessWidget {
  final bool isLogin;
  final bool loading;
  final bool obscurePassword;
  final String? error;
  final String? info;
  final String? tipoAttivita;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nomeCtrl;
  final TextEditingController cognomeCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController codiceFiscaleCtrl;
  final TextEditingController nomeAziendaCtrl;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onTipoChanged;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final bool padded;
  final bool showMobileHeader;

  const _FormPane({
    required this.isLogin,
    required this.loading,
    required this.obscurePassword,
    required this.error,
    required this.info,
    required this.tipoAttivita,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nomeCtrl,
    required this.cognomeCtrl,
    required this.telefonoCtrl,
    required this.codiceFiscaleCtrl,
    required this.nomeAziendaCtrl,
    required this.onToggleObscure,
    required this.onTipoChanged,
    required this.onSubmit,
    required this.onToggleMode,
    this.padded = false,
    this.showMobileHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showMobileHeader) ...[
        const Text(
          'MUD',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin ? 'Accedi al tuo account' : 'Crea un nuovo account',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 16),
        ),
        const SizedBox(height: 40),
      ] else ...[
        Text(
          isLogin ? 'Accedi' : 'Crea un account',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin
              ? 'Inserisci le credenziali per entrare nel marketplace.'
              : 'Compila i dati per registrare la tua azienda su MUD.',
          style: const TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.35),
        ),
        const SizedBox(height: 28),
      ],
      if (!isLogin) ...[
        formLabel('Nome'),
        formTextField(controller: nomeCtrl, hint: 'Mario'),
        const SizedBox(height: 16),
        formLabel('Cognome'),
        formTextField(controller: cognomeCtrl, hint: 'Rossi'),
        const SizedBox(height: 16),
        formLabel('Telefono'),
        formTextField(controller: telefonoCtrl, hint: '+39...', keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        formLabel('Codice fiscale'),
        formTextField(controller: codiceFiscaleCtrl, hint: 'RSSMRA80A01H501U'),
        const SizedBox(height: 16),
        formLabel('Nome azienda'),
        formTextField(controller: nomeAziendaCtrl, hint: 'La mia azienda Srl'),
        const SizedBox(height: 16),
        formLabel('Tipo attività'),
        Row(
          children: [
            Expanded(
              child: _RoleChoice(
                label: 'Fornitore',
                selected: tipoAttivita == 'Fornitore',
                onTap: () => onTipoChanged('Fornitore'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleChoice(
                label: 'Acquirente',
                selected: tipoAttivita == 'Acquirente',
                onTap: () => onTipoChanged('Acquirente'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Questa scelta non potrà essere modificata in seguito.',
          style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
      formLabel('Email'),
      formTextField(controller: emailCtrl, hint: 'nome@azienda.it', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      formLabel('Password'),
      formTextField(
        controller: passwordCtrl,
        hint: 'Minimo 6 caratteri',
        obscureText: obscurePassword,
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          icon: Icon(
            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textGrey,
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error!, style: const TextStyle(color: AppColors.danger)),
      ],
      if (info != null) ...[
        const SizedBox(height: 14),
        Text(info!, style: const TextStyle(color: AppColors.green)),
      ],
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isLogin ? 'Accedi' : 'Registrati',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: loading ? null : onToggleMode,
        child: Text(
          isLogin ? 'Non hai un account? Registrati' : 'Hai già un account? Accedi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ];

    final list = ListView(
      padding: padded
          ? EdgeInsets.fromLTRB(showMobileHeader ? 24 : 32, showMobileHeader ? 48 : 32, showMobileHeader ? 24 : 32, 28)
          : EdgeInsets.zero,
      children: children,
    );

    return list;
  }
}

class _RoleChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
