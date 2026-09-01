import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/section_header.dart';

/// Pagina prezzi / commissioni marketplace (pubblica).
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Prezzi'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SectionHeader(
            title: 'Prezzi trasparenti',
            subtitle: 'Pubblicare è gratis. Paghi solo quando vendi.',
          ),
          const SizedBox(height: 24),
          _card(
            title: 'Annunci',
            price: '0 €',
            detail: 'Creazione e gestione annunci illimitata per aziende verificate. Nessun canone mensile.',
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Commissione MUD',
            price: '5%',
            detail:
                'Sull\'importo pagato dall\'acquirente tratteniamo il 5% (application fee Stripe Connect). Il resto va al venditore sul suo account Connect.',
            highlight: true,
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Costi Stripe',
            price: 'Stripe',
            detail:
                'Le commissioni di elaborazione carte di Stripe sono a carico della transazione secondo le tariffe Stripe in vigore (test o live). Non sono una fee aggiuntiva MUD.',
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Chat e ordini',
            price: 'Inclusi',
            detail:
                'Messaggistica tra aziende, checkout Stripe e tracciamento ordine (pagato → confermato → preparazione → spedito → completato) sono inclusi.',
          ),
          const SizedBox(height: 28),
          Text(
            'Esempio',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ordine da 1.000 € → commissione MUD 50 € → circa 950 € al venditore (prima delle fee di elaborazione Stripe).',
            style: TextStyle(color: AppColors.textGrey, height: 1.45),
          ),
          const SizedBox(height: 20),
          Text(
            'Per ricevere i pagamenti il venditore deve completare l\'onboarding Stripe Connect dal Profilo.',
            style: TextStyle(color: AppColors.textLightGrey, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String price,
    required String detail,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  color: highlight ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: TextStyle(color: AppColors.textGrey, height: 1.45, fontSize: 14)),
        ],
      ),
    );
  }
}
