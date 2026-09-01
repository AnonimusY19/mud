import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models/address.dart';
import '../models/profile.dart';
import '../services/payment_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_fields.dart';
import '../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _paymentService = PaymentService();
  final _emailCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _codiceFiscaleCtrl = TextEditingController();
  final _nomeAziendaCtrl = TextEditingController();
  final _partitaIvaCtrl = TextEditingController();
  final _codiceSdiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _localitaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _tipoAttivitaCtrl = TextEditingController();
  String? _logoUrl;
  Address _address = const Address(formattedAddress: '');
  bool _loading = true;
  bool _saving = false;
  bool _stripeBusy = false;
  StripeConnectStatus? _stripeStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromAppState());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _codiceFiscaleCtrl.dispose();
    _nomeAziendaCtrl.dispose();
    _partitaIvaCtrl.dispose();
    _codiceSdiCtrl.dispose();
    _descCtrl.dispose();
    _localitaCtrl.dispose();
    _telefonoCtrl.dispose();
    _tipoAttivitaCtrl.dispose();
    super.dispose();
  }

  void _applyProfile(Profile profile, {required String email}) {
    _emailCtrl.text = email;
    _nomeCtrl.text = profile.nome;
    _cognomeCtrl.text = profile.cognome;
    _codiceFiscaleCtrl.text = profile.codiceFiscale;
    _nomeAziendaCtrl.text = profile.nomeAzienda;
    _partitaIvaCtrl.text = profile.partitaIva;
    _codiceSdiCtrl.text = profile.codiceSdi;
    _descCtrl.text = profile.descrizione;
    _localitaCtrl.text = profile.localita;
    _telefonoCtrl.text = profile.telefono;
    _tipoAttivitaCtrl.text = profile.tipoAttivita;
    _logoUrl = profile.logoUrl;
    _address = profile.address.formattedAddress.isNotEmpty
        ? profile.address
        : Address(formattedAddress: profile.localita);
  }

  void _hydrateFromAppState() {
    final appState = AppScope.of(context);
    final cached = appState.profile;
    if (cached != null) {
      _applyProfile(cached, email: appState.currentUserEmail ?? '');
      if (mounted) setState(() => _loading = false);
      unawaited(_refreshStripeStatus());
      return;
    }
    unawaited(_loadProfile());
  }

  Future<void> _refreshStripeStatus() async {
    final profile = AppScope.of(context).profile;
    if (profile != null && !profile.isSellerRole) {
      if (mounted) setState(() => _stripeStatus = null);
      return;
    }
    try {
      final status = await _paymentService.fetchConnectStatus();
      if (!mounted) return;
      setState(() => _stripeStatus = status);
    } catch (_) {
      // Secrets Stripe non ancora configurati: UI resta in stato sconosciuto.
    }
  }

  Future<void> _startStripeOnboarding() async {
    final profile = AppScope.of(context).profile;
    if (profile != null && !profile.isSellerRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stripe Connect è riservato a fornitori e profili misti')),
      );
      return;
    }
    setState(() => _stripeBusy = true);
    try {
      final url = await _paymentService.startConnectOnboarding();
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire Stripe')),
        );
      }
      await _refreshStripeStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _stripeBusy = false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await AppScope.of(context).loadProfile();
      if (!mounted) return;
      _applyProfile(profile, email: AppScope.of(context).currentUserEmail ?? '');
      unawaited(_refreshStripeStatus());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile caricare il profilo')),
        );
        await Supabase.instance.client.auth.signOut();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final appState = AppScope.of(context);
    final address = _address.formattedAddress.trim().isNotEmpty
        ? _address
        : Address(formattedAddress: _localitaCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final saved = await _profileService.saveCompanyProfile(
        nomeAzienda: _nomeAziendaCtrl.text,
        descrizione: _descCtrl.text,
        address: address,
        logoUrl: _logoUrl,
        modalita: appState.mode,
      );
      // Mantieni i campi identità già in cache (save company non li riscrive tutti)
      final merged = Profile(
        id: saved.id,
        nome: _nomeCtrl.text,
        cognome: _cognomeCtrl.text,
        codiceFiscale: _codiceFiscaleCtrl.text,
        nomeAzienda: saved.nomeAzienda,
        partitaIva: _partitaIvaCtrl.text,
        codiceSdi: _codiceSdiCtrl.text,
        tipoAttivita: _tipoAttivitaCtrl.text.isNotEmpty ? _tipoAttivitaCtrl.text : saved.tipoAttivita,
        descrizione: saved.descrizione,
        localita: saved.localita,
        telefono: _telefonoCtrl.text,
        logoUrl: saved.logoUrl,
        modalita: saved.modalita,
        address: saved.address,
        stripeAccountId: saved.stripeAccountId,
        stripeChargesEnabled: saved.stripeChargesEnabled,
        stripeDetailsSubmitted: saved.stripeDetailsSubmitted,
      );
      appState.setProfile(merged);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato su Supabase')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il salvataggio')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SectionHeader(title: 'Profilo', subtitle: 'Gestisci la tua azienda e le impostazioni'),
        const SizedBox(height: 20),
        if (AppScope.of(context).profile?.isSellerRole == true) ...[
          _SellerOnboardingCard(
            profileComplete: _nomeAziendaCtrl.text.trim().isNotEmpty &&
                _partitaIvaCtrl.text.trim().isNotEmpty &&
                _localitaCtrl.text.trim().isNotEmpty,
            stripeReady: _stripeStatus?.ready == true ||
                (AppScope.of(context).profile?.stripeReady ?? false),
            hasListing: AppScope.of(context).myListings.isNotEmpty,
            onOpenStripe: _startStripeOnboarding,
            stripeBusy: _stripeBusy,
          ),
          const SizedBox(height: 24),
        ],
        Center(
          child: _logoUrl != null && _logoUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    _logoUrl!,
                    fit: BoxFit.cover,
                    width: 96,
                    height: 96,
                    errorBuilder: (_, _, _) => const AppLogo(size: 96, borderRadius: 24),
                  ),
                )
              : const AppLogo(size: 96, borderRadius: 24),
        ),
        const SizedBox(height: 28),
        Text('DATI PERSONALI', style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        formLabel('Nome'),
        formTextField(controller: _nomeCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Cognome'),
        formTextField(controller: _cognomeCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Codice fiscale'),
        formTextField(controller: _codiceFiscaleCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Telefono'),
        formTextField(controller: _telefonoCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Email'),
        formTextField(controller: _emailCtrl, readOnly: true),
        const SizedBox(height: 28),
        Text('AZIENDA', style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        formLabel('Ragione sociale'),
        formTextField(controller: _nomeAziendaCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Partita IVA'),
        formTextField(controller: _partitaIvaCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Codice destinatario SDI'),
        formTextField(controller: _codiceSdiCtrl, readOnly: true),
        const SizedBox(height: 20),
        formLabel('Tipo attività'),
        formTextField(controller: _tipoAttivitaCtrl, readOnly: true),
        const SizedBox(height: 8),
        Text(
          'Dati fiscali e ruolo scelti in registrazione: non modificabili.',
          style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        formLabel('Descrizione'),
        formTextField(controller: _descCtrl, maxLines: 4, hint: 'Descrivi la tua attività...'),
        const SizedBox(height: 20),
        formLabel('Indirizzo di sede legale'),
        AddressAutocompleteField(
          controller: _localitaCtrl,
          initialAddress: _address,
          hint: 'Es. Via Roma 10, Milano',
          onAddressSelected: (address) => setState(() => _address = address),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: const Text('Salva profilo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (AppScope.of(context).profile?.isSellerRole == true) ...[
          Divider(color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            'PAGAMENTI',
            style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamenti Stripe',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _stripeStatus?.ready == true
                      ? 'Account collegato: puoi ricevere pagamenti dagli acquirenti.'
                      : (_stripeStatus?.detailsSubmitted == true
                          ? 'Onboarding inviato: in attesa di verifica Stripe.'
                          : 'Collega Stripe Connect per ricevere i pagamenti degli ordini.'),
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stripeBusy ? null : _startStripeOnboarding,
                    icon: _stripeBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _stripeStatus?.ready == true
                                ? Icons.check_circle_outline
                                : Icons.account_balance_outlined,
                          ),
                    label: Text(
                      _stripeStatus?.ready == true
                          ? 'Aggiorna / gestisci Stripe'
                          : 'Collega account Stripe',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Esci', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SellerOnboardingCard extends StatelessWidget {
  final bool profileComplete;
  final bool stripeReady;
  final bool hasListing;
  final VoidCallback onOpenStripe;
  final bool stripeBusy;

  const _SellerOnboardingCard({
    required this.profileComplete,
    required this.stripeReady,
    required this.hasListing,
    required this.onOpenStripe,
    required this.stripeBusy,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      profileComplete,
      stripeReady,
      hasListing,
    ];
    final done = steps.where((e) => e).length;
    final allDone = done == steps.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone
              ? AppColors.green.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allDone ? 'Pronto a vendere' : 'Checklist venditore',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$done/3',
                style: TextStyle(
                  color: allDone ? AppColors.green : AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            allDone
                ? 'Azienda, Stripe e primo annuncio sono a posto.'
                : 'Completa questi passi per ricevere pagamenti sugli annunci.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _step(
            done: profileComplete,
            title: 'Dati azienda',
            subtitle: 'Ragione sociale, P.IVA e sede legale',
          ),
          _step(
            done: stripeReady,
            title: 'Stripe Connect',
            subtitle: stripeReady
                ? 'Account collegato e abilitato ai pagamenti'
                : 'Collega l\'account per incassare',
            action: stripeReady
                ? null
                : TextButton(
                    onPressed: stripeBusy ? null : onOpenStripe,
                    child: const Text('Collega Stripe'),
                  ),
          ),
          _step(
            done: hasListing,
            title: 'Primo annuncio',
            subtitle: hasListing
                ? 'Hai già almeno un annuncio pubblicato'
                : 'Pubblica da «I miei annunci»',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _step({
    required bool done,
    required String title,
    required String subtitle,
    Widget? action,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppColors.green : AppColors.textGrey,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                if (action != null) action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
