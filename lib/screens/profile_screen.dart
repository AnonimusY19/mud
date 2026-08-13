import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../models/address.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_fields.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
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
      return;
    }
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await AppScope.of(context).loadProfile();
      if (!mounted) return;
      _applyProfile(profile, email: AppScope.of(context).currentUserEmail ?? '');
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
    final appState = AppScope.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SectionHeader(title: 'Profilo', subtitle: 'Gestisci la tua azienda e le impostazioni'),
        const SizedBox(height: 24),
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
        const Text('DATI PERSONALI', style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
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
        const Text('AZIENDA', style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
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
        const Text(
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
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),
        const Text('IMPOSTAZIONI', style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modalità', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Compra o vendi', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  ],
                ),
              ),
              ModeToggle(mode: appState.mode, onChanged: appState.setMode),
            ],
          ),
        ),
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
