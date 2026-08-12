import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../models/address.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/address_autocomplete_field.dart';
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
  final _descCtrl = TextEditingController();
  final _localitaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String _tipoAttivita = 'Entrambi';
  String? _logoUrl;
  Address _address = const Address(formattedAddress: '');
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _codiceFiscaleCtrl.dispose();
    _nomeAziendaCtrl.dispose();
    _descCtrl.dispose();
    _localitaCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _profileService.fetchCurrentProfile();
      if (!mounted) return;
      _emailCtrl.text = _profileService.currentUserEmail ?? '';
      if (profile != null) {
        _nomeCtrl.text = profile.nome;
        _cognomeCtrl.text = profile.cognome;
        _codiceFiscaleCtrl.text = profile.codiceFiscale;
        _nomeAziendaCtrl.text = profile.nomeAzienda;
        _descCtrl.text = profile.descrizione;
        _localitaCtrl.text = profile.localita;
        _telefonoCtrl.text = profile.telefono;
        _tipoAttivita = profile.tipoAttivita;
        _logoUrl = profile.logoUrl;
        _address = profile.address.formattedAddress.isNotEmpty
            ? profile.address
            : Address(formattedAddress: profile.localita);
        AppScope.of(context).setMode(profile.modalita);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile caricare il profilo')),
        );
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
      await _profileService.saveCompanyProfile(
        nomeAzienda: _nomeAziendaCtrl.text,
        tipoAttivita: _tipoAttivita,
        descrizione: _descCtrl.text,
        address: address,
        logoUrl: _logoUrl,
        modalita: appState.mode,
      );
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
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _logoUrl != null && _logoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(_logoUrl!, fit: BoxFit.cover, width: 96, height: 96),
                  )
                : const Icon(Icons.business, color: Colors.white, size: 40),
          ),
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
        formLabel('Nome azienda'),
        formTextField(controller: _nomeAziendaCtrl),
        const SizedBox(height: 20),
        formLabel('Tipo attività'),
        Row(
          children: [
            Expanded(child: _ActivityButton(label: 'Fornitore', selected: _tipoAttivita == 'Fornitore', onTap: () => setState(() => _tipoAttivita = 'Fornitore'))),
            const SizedBox(width: 10),
            Expanded(child: _ActivityButton(label: 'Acquirente', selected: _tipoAttivita == 'Acquirente', onTap: () => setState(() => _tipoAttivita = 'Acquirente'))),
            const SizedBox(width: 10),
            Expanded(child: _ActivityButton(label: 'Entrambi', selected: _tipoAttivita == 'Entrambi', onTap: () => setState(() => _tipoAttivita = 'Entrambi'))),
          ],
        ),
        const SizedBox(height: 20),
        formLabel('Descrizione'),
        formTextField(controller: _descCtrl, maxLines: 4, hint: 'Descrivi la tua attività...'),
        const SizedBox(height: 20),
        formLabel('Indirizzo'),
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
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modalità', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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

class _ActivityButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
