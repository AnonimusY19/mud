import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address.dart';
import '../theme/app_colors.dart';
import '../services/profile_service.dart';
import '../services/vies_service.dart';
import '../utils/codice_fiscale.dart';
import '../utils/codice_sdi.dart';
import '../utils/partita_iva.dart';
import '../utils/phone_number.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_fields.dart';

// OTP SMS disabilitato temporaneamente (manca provider Twilio).
// Per riattivarlo: usare RegistrationOtpScreen + PhoneAuthService al posto del signUp diretto.

class AuthScreen extends StatefulWidget {
  final String? initialMessage;
  final bool startOnRegister;

  const AuthScreen({
    super.key,
    this.initialMessage,
    this.startOnRegister = false,
  });

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
  final _sedeLegaleCtrl = TextEditingController();
  final _partitaIvaCtrl = TextEditingController();
  final _codiceSdiCtrl = TextEditingController();

  late bool _isLogin;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _tipoAttivita; // 'Fornitore' | 'Acquirente' | 'Entrambi'
  String? _error;
  String? _info;
  Address? _sedeLegale;

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
    _isLogin = !widget.startOnRegister;
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
    _sedeLegaleCtrl.dispose();
    _partitaIvaCtrl.dispose();
    _codiceSdiCtrl.dispose();
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
        _nomeAziendaCtrl.text.trim().isEmpty ||
        _sedeLegaleCtrl.text.trim().isEmpty ||
        _partitaIvaCtrl.text.trim().isEmpty ||
        _codiceSdiCtrl.text.trim().isEmpty) {
      setState(() {
        _error =
            'Compila tutti i campi obbligatori: anagrafica, ragione sociale, sede legale, Partita IVA e codice SDI';
        _info = null;
      });
      return false;
    }

    if (_sedeLegale == null || _sedeLegale!.isEmpty) {
      setState(() {
        _error = 'Seleziona l\'indirizzo di sede legale dai suggerimenti';
        _info = null;
      });
      return false;
    }

    if (_tipoAttivita != 'Fornitore' &&
        _tipoAttivita != 'Acquirente' &&
        _tipoAttivita != 'Entrambi') {
      setState(() {
        _error = 'Scegli se sei un fornitore, un acquirente o entrambi';
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

    final pivaError = PartitaIva.validate(_partitaIvaCtrl.text);
    if (pivaError != null) {
      setState(() {
        _error = pivaError;
        _info = null;
      });
      return false;
    }

    final sdiError = CodiceSdi.validate(_codiceSdiCtrl.text);
    if (sdiError != null) {
      setState(() {
        _error = sdiError;
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
        if (!mounted) return;
        _closeAfterAuth();
      } else {
        final vies = await ViesService().checkItalianVat(_partitaIvaCtrl.text);
        if (!mounted) return;
        switch (vies) {
          case ViesInvalid(:final message):
            setState(() {
              _loading = false;
              _error = message;
              _info = null;
            });
            return;
          case ViesUnavailable(:final message):
            setState(() {
              _loading = false;
              _error = message;
              _info = null;
            });
            return;
          case ViesValid(:final verificationId, :final vatNumber):
            // ok — usa verificationId nel signup
            final nome = _nomeCtrl.text.trim();
            final cognome = _cognomeCtrl.text.trim();
            final telefono = PhoneNumber.normalize(_telefonoCtrl.text)!;
            final codiceFiscale = _codiceFiscaleCtrl.text.trim().toUpperCase();
            final nomeAzienda = _nomeAziendaCtrl.text.trim();
            final partitaIva = vatNumber;
            final codiceSdi = CodiceSdi.normalize(_codiceSdiCtrl.text);
            final sedeLegale = _sedeLegale!;
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
                'partita_iva': partitaIva,
                'codice_sdi': codiceSdi,
                'tipo_attivita': tipoAttivita,
                'vies_verification_id': verificationId,
                ...sedeLegale.toProfileJson().map((k, v) => MapEntry(k, v?.toString() ?? '')),
              },
            );

            if (response.session != null) {
              await ProfileService().saveIdentityFields(
                nome: nome,
                cognome: cognome,
                telefono: telefono,
                codiceFiscale: codiceFiscale,
                nomeAzienda: nomeAzienda,
                partitaIva: partitaIva,
                codiceSdi: codiceSdi,
                sedeLegale: sedeLegale,
                tipoAttivita: tipoAttivita,
              );
            }

            if (!mounted) return;
            if (response.session == null) {
              setState(() {
                _isLogin = true;
                _info =
                    'Registrazione riuscita. Controlla la casella email e conferma l\'account, poi accedi.';
              });
            } else {
              _closeAfterAuth();
            }
            break;
        }
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _closeAfterAuth() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
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
    final closeBar = Navigator.of(context).canPop()
        ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Chiudi',
              icon: Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        : null;

    if (_useSplitLayout(context)) {
      final isRegister = !_isLogin;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: closeBar,
        body: Row(
          children: [
            Expanded(flex: isRegister ? 3 : 5, child: _BrandingPane(isLogin: _isLogin)),
            Expanded(
              flex: isRegister ? 7 : 6,
              child: ColoredBox(
                color: const Color(0xFF0B1B33),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = isRegister
                        ? (constraints.maxWidth - 40).clamp(520.0, 980.0)
                        : 480.0;
                    final maxHeight = isRegister
                        ? (constraints.maxHeight - 24).clamp(480.0, 1200.0)
                        : 720.0;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(
                            horizontal: isRegister ? 20 : 28,
                            vertical: isRegister ? 12 : 24,
                          ),
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
                              sedeLegaleCtrl: _sedeLegaleCtrl,
                              partitaIvaCtrl: _partitaIvaCtrl,
                              codiceSdiCtrl: _codiceSdiCtrl,
                              sedeLegale: _sedeLegale,
                              onSedeLegaleSelected: (address) => setState(() => _sedeLegale = address),
                              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                              onTipoChanged: (v) => setState(() => _tipoAttivita = v),
                              onSubmit: _submit,
                              onToggleMode: _toggleMode,
                              padded: true,
                              wideRegister: isRegister,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
      appBar: closeBar,
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
          sedeLegaleCtrl: _sedeLegaleCtrl,
          partitaIvaCtrl: _partitaIvaCtrl,
          codiceSdiCtrl: _codiceSdiCtrl,
          sedeLegale: _sedeLegale,
          onSedeLegaleSelected: (address) => setState(() => _sedeLegale = address),
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
                  const AppLogo(size: 48, borderRadius: 14),
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
  final TextEditingController sedeLegaleCtrl;
  final TextEditingController partitaIvaCtrl;
  final TextEditingController codiceSdiCtrl;
  final Address? sedeLegale;
  final ValueChanged<Address> onSedeLegaleSelected;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onTipoChanged;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final bool padded;
  final bool showMobileHeader;
  final bool wideRegister;

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
    required this.sedeLegaleCtrl,
    required this.partitaIvaCtrl,
    required this.codiceSdiCtrl,
    required this.sedeLegale,
    required this.onSedeLegaleSelected,
    required this.onToggleObscure,
    required this.onTipoChanged,
    required this.onSubmit,
    required this.onToggleMode,
    this.padded = false,
    this.showMobileHeader = false,
    this.wideRegister = false,
  });

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formLabel(label, compact: wideRegister),
        child,
      ],
    );
  }

  Widget _pair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: wideRegister ? 14 : 10),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = wideRegister ? 10.0 : 16.0;
    final children = <Widget>[
      if (showMobileHeader) ...[
        const Center(child: AppLogo(size: 64, borderRadius: 16)),
        const SizedBox(height: 12),
        const Text(
          'MUD',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin ? 'Accedi al tuo account' : 'Crea un nuovo account',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 16),
        ),
        SizedBox(height: wideRegister ? 16 : 32),
      ] else ...[
        Text(
          isLogin ? 'Accedi' : 'Crea un account',
          style: TextStyle(
            fontSize: wideRegister ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLogin
              ? 'Inserisci le credenziali per entrare nel marketplace.'
              : 'Compila i dati per registrare la tua azienda su MUD.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.35),
        ),
        SizedBox(height: wideRegister ? 14 : 28),
      ],
      if (!isLogin) ...[
        if (wideRegister) ...[
          _pair(
            _field('Nome', formTextField(controller: nomeCtrl, hint: 'Mario', dense: true)),
            _field('Cognome', formTextField(controller: cognomeCtrl, hint: 'Rossi', dense: true)),
          ),
          SizedBox(height: gap),
          _pair(
            _field('Telefono', formTextField(controller: telefonoCtrl, hint: '+39...', keyboardType: TextInputType.phone, dense: true)),
            _field('Codice fiscale', formTextField(controller: codiceFiscaleCtrl, hint: 'RSSMRA80A01H501U', dense: true)),
          ),
          SizedBox(height: gap),
          _pair(
            _field('Ragione sociale', formTextField(controller: nomeAziendaCtrl, hint: 'Rossi Foods Srl', dense: true)),
            _field(
              'Partita IVA',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  formTextField(controller: partitaIvaCtrl, hint: '12345678901', keyboardType: TextInputType.number, dense: true),
                  const SizedBox(height: 4),
                  Text(
                    'Verificata sul server via VIES (UE) al momento della registrazione.',
                    style: TextStyle(color: AppColors.textLightGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),
          _field('Codice destinatario SDI', formTextField(controller: codiceSdiCtrl, hint: 'ABCDEFG', dense: true)),
          SizedBox(height: gap),
          _field(
            'Tipo attività',
            Row(
              children: [
                Expanded(
                  child: _RoleChoice(
                    label: 'Fornitore',
                    selected: tipoAttivita == 'Fornitore',
                    onTap: () => onTipoChanged('Fornitore'),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RoleChoice(
                    label: 'Acquirente',
                    selected: tipoAttivita == 'Acquirente',
                    onTap: () => onTipoChanged('Acquirente'),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RoleChoice(
                    label: 'Entrambi',
                    selected: tipoAttivita == 'Entrambi',
                    onTap: () => onTipoChanged('Entrambi'),
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Il tipo di attivita non potra essere modificato in seguito. Solo Fornitore/Entrambi collegano Stripe.',
            style: TextStyle(color: AppColors.textLightGrey, fontSize: 11),
          ),
          SizedBox(height: gap),
          _field(
            'Indirizzo di sede legale',
            AddressAutocompleteField(
              controller: sedeLegaleCtrl,
              initialAddress: sedeLegale,
              hint: 'Es. Via Roma 10, Milano',
              onAddressSelected: onSedeLegaleSelected,
            ),
          ),
          SizedBox(height: gap),
          _pair(
            _field('Email', formTextField(controller: emailCtrl, hint: 'nome@azienda.it', keyboardType: TextInputType.emailAddress, dense: true)),
            _field(
              'Password',
              formTextField(
                controller: passwordCtrl,
                hint: 'Minimo 6 caratteri',
                obscureText: obscurePassword,
                dense: true,
                suffixIcon: IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          formLabel('Nome'),
          formTextField(controller: nomeCtrl, hint: 'Mario'),
          SizedBox(height: gap),
          formLabel('Cognome'),
          formTextField(controller: cognomeCtrl, hint: 'Rossi'),
          SizedBox(height: gap),
          formLabel('Telefono'),
          formTextField(controller: telefonoCtrl, hint: '+39...', keyboardType: TextInputType.phone),
          SizedBox(height: gap),
          formLabel('Codice fiscale'),
          formTextField(controller: codiceFiscaleCtrl, hint: 'RSSMRA80A01H501U'),
          SizedBox(height: gap),
          formLabel('Ragione sociale'),
          formTextField(controller: nomeAziendaCtrl, hint: 'Rossi Foods Srl'),
          SizedBox(height: gap),
          formLabel('Indirizzo di sede legale'),
          AddressAutocompleteField(
            controller: sedeLegaleCtrl,
            initialAddress: sedeLegale,
            hint: 'Es. Via Roma 10, Milano',
            onAddressSelected: onSedeLegaleSelected,
          ),
          SizedBox(height: gap),
          formLabel('Partita IVA'),
          formTextField(controller: partitaIvaCtrl, hint: '12345678901', keyboardType: TextInputType.number),
          const SizedBox(height: 4),
          Text(
            'Verificata sul server via VIES (UE) al momento della registrazione.',
            style: TextStyle(color: AppColors.textLightGrey, fontSize: 11),
          ),
          SizedBox(height: gap),
          formLabel('Codice destinatario SDI'),
          formTextField(controller: codiceSdiCtrl, hint: 'ABCDEFG'),
          SizedBox(height: gap),
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
              const SizedBox(width: 10),
              Expanded(
                child: _RoleChoice(
                  label: 'Entrambi',
                  selected: tipoAttivita == 'Entrambi',
                  onTap: () => onTipoChanged('Entrambi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Questa scelta non potra essere modificata. Solo Fornitore/Entrambi collegano Stripe.',
            style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
          ),
          SizedBox(height: gap),
        ],
      ],
      if (isLogin || !wideRegister) ...[
        formLabel('Email'),
        formTextField(controller: emailCtrl, hint: 'nome@azienda.it', keyboardType: TextInputType.emailAddress),
        SizedBox(height: gap),
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
      ],
      if (error != null) ...[
        const SizedBox(height: 10),
        Text(error!, style: const TextStyle(color: AppColors.danger)),
      ],
      if (info != null) ...[
        const SizedBox(height: 10),
        Text(info!, style: const TextStyle(color: AppColors.green)),
      ],
      SizedBox(height: wideRegister ? 16 : 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: wideRegister ? 14 : 16),
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
      const SizedBox(height: 8),
      TextButton(
        onPressed: loading ? null : onToggleMode,
        child: Text(
          isLogin ? 'Non hai un account? Registrati' : 'Hai già un account? Accedi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ];

    final padding = padded
        ? EdgeInsets.fromLTRB(
            showMobileHeader ? 24 : (wideRegister ? 28 : 32),
            showMobileHeader ? 48 : (wideRegister ? 20 : 32),
            showMobileHeader ? 24 : (wideRegister ? 28 : 32),
            wideRegister ? 16 : 28,
          )
        : EdgeInsets.zero;

    if (wideRegister) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
    }

    return ListView(padding: padding, children: children);
  }
}

class _RoleChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _RoleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 11 : 14),
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
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}
