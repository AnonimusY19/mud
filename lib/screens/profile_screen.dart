import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/form_fields.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nomeCtrl = TextEditingController(text: 'Francesco Piano');
  final _descCtrl = TextEditingController();
  final _localitaCtrl = TextEditingController(text: 'Roma');
  final _telefonoCtrl = TextEditingController();
  String _tipoAttivita = 'Entrambi';

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _localitaCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SectionHeader(title: 'Profilo', subtitle: 'Gestisci la tua azienda e le impostazioni'),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Container(
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
                child: const Icon(Icons.business, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 10),
              const Text('Tocca per cambiare logo', style: TextStyle(color: AppColors.textGrey)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        formLabel('Nome azienda'),
        formTextField(controller: _nomeCtrl),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [formLabel('Località'), formTextField(controller: _localitaCtrl)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [formLabel('Telefono'), formTextField(controller: _telefonoCtrl, hint: '+39...', keyboardType: TextInputType.phone)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profilo salvato')));
            },
            icon: const Icon(Icons.check),
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
            onPressed: () {},
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Esci', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.danger.withOpacity(0.35)),
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