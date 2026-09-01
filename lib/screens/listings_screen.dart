import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../widgets/edit_listing_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/my_listing_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/stripe_seller_gate.dart';

class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final listings = appState.myListings;
    final needsStripe = appState.profile?.needsStripeOnboarding == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SectionHeader(title: 'I miei annunci', subtitle: 'Gestisci le tue pubblicazioni'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openEditor(context, appState, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuovo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
        if (needsStripe) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
            ),
            child: Text(
              'Collega Stripe Connect (Profilo o banner in alto) prima di creare annunci.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (appState.listingsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (appState.listingsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Text(appState.listingsError!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: appState.loadListings, child: const Text('Riprova')),
                ],
              ),
            ),
          )
        else if (listings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: EmptyState(
                icon: Icons.campaign_outlined,
                title: 'Nessun annuncio',
                subtitle: needsStripe
                    ? 'Completa Stripe Connect per pubblicare'
                    : 'Crea il tuo primo annuncio',
              ),
            ),
          )
        else
          for (final listing in listings)
            MyListingTile(
              listing: listing,
              onEdit: () => _openEditor(context, appState, listing),
              onDelete: () => _confirmDelete(context, appState, listing),
            ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, AppState appState, Listing? listing) async {
    if (listing == null && appState.profile?.needsStripeOnboarding == true) {
      await showStripeRequiredDialogIfNeeded(context);
      if (appState.profile?.needsStripeOnboarding == true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devi completare Stripe Connect prima di aggiungere annunci'),
          ),
        );
        return;
      }
    }

    final result = await showDialog<Listing>(
      context: context,
      builder: (_) => EditListingDialog(listing: listing),
    );
    if (result == null) return;
    try {
      if (listing == null) {
        await appState.addListing(result);
      } else {
        await appState.updateListing(result);
      }
    } catch (e) {
      if (!context.mounted) return;
      final raw = e.toString();
      final message = raw.contains('Stripe Connect')
          ? 'Collega Stripe Connect prima di pubblicare annunci'
          : 'Errore nel salvataggio dell\'annuncio';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState appState, Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina annuncio'),
        content: Text('Vuoi eliminare "${listing.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await appState.deleteListing(listing.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nell\'eliminazione dell\'annuncio')),
      );
    }
  }
}
