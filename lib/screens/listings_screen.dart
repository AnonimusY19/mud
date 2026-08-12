import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../widgets/edit_listing_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/my_listing_tile.dart';
import '../widgets/section_header.dart';

class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final listings = appState.myListings;

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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: EmptyState(icon: Icons.campaign_outlined, title: 'Nessun annuncio', subtitle: 'Crea il tuo primo annuncio'),
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
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel salvataggio dell\'annuncio')),
      );
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
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina', style: TextStyle(color: AppColors.danger))),
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
