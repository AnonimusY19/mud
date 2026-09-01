import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/listing.dart';
import '../screens/channel_page.dart';
import '../services/stream_chat_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_navigation.dart';
import 'type_badge.dart';

class ListingDetailDialog extends StatelessWidget {
  final Listing listing;
  final bool isGuestPreview;

  const ListingDetailDialog({
    super.key,
    required this.listing,
    this.isGuestPreview = false,
  });

  static Future<void> open(
    BuildContext context,
    Listing listing, {
    bool isGuestPreview = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => ListingDetailDialog(
        listing: listing,
        isGuestPreview: isGuestPreview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final maxWidth = wide ? 920.0 : size.width - 32;
    final maxHeight = wide ? 520.0 : size.height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              wide
                  ? SizedBox(
                      height: maxHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _ImagePane(listing: listing)),
                          Expanded(
                            flex: 5,
                            child: _DetailsPane(
                              listing: listing,
                              expanded: true,
                              isGuestPreview: isGuestPreview,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 220, width: double.infinity, child: _ImagePane(listing: listing)),
                          _DetailsPane(
                            listing: listing,
                            expanded: false,
                            isGuestPreview: isGuestPreview,
                          ),
                        ],
                      ),
                    ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.95),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePane extends StatelessWidget {
  final Listing listing;
  const _ImagePane({required this.listing});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceGrey,
      child: listing.imageUrl != null && listing.imageUrl!.isNotEmpty
          ? Image.network(
              listing.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.sell_outlined, size: 72, color: AppColors.green),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  final Listing listing;
  final bool expanded;
  final bool isGuestPreview;
  const _DetailsPane({
    required this.listing,
    required this.expanded,
    this.isGuestPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = listing.address.formattedAddress;
    final location = listing.location;
    final fullAddress = formatted.isNotEmpty ? formatted : location;
    final cityOnly = listing.address.displayCity;
    final address = isGuestPreview
        ? (cityOnly.isNotEmpty ? cityOnly : 'Località disponibile dopo accesso')
        : fullAddress;
    final companyRaw = listing.displayCompanyName.trim();
    final company = isGuestPreview
        ? 'Azienda verificata'
        : (companyRaw.isNotEmpty ? companyRaw : 'Azienda non indicata');
    final title = listing.displayTitle;
    final category = listing.category;
    final unit = listing.unit;
    final description = listing.description;
    final previewDescription = description.trim().isEmpty
        ? ''
        : (description.length <= 120 ? description : '${description.substring(0, 120)}…');

    final content = <Widget>[
      TypeBadge(type: listing.type),
      const SizedBox(height: 14),
      Text(
        title,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.textPrimary),
      ),
      const SizedBox(height: 6),
      Text(
        company,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textLightGrey),
      ),
      const SizedBox(height: 16),
      _InfoRow(label: 'Categoria', value: category),
      const SizedBox(height: 10),
      _InfoRow(label: isGuestPreview ? 'Zona' : 'Indirizzo', value: address.isNotEmpty ? address : '—'),
      const SizedBox(height: 10),
      _InfoRow(
        label: 'Prezzo',
        value: isGuestPreview
            ? 'da €${listing.price.toStringAsFixed(0)} / $unit'
            : '€${listing.price.toStringAsFixed(2)} / $unit',
        valueStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
      ),
      if ((isGuestPreview ? previewDescription : description).trim().isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Descrizione', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textLightGrey)),
        const SizedBox(height: 6),
        Text(
          isGuestPreview ? previewDescription : description,
          style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textGrey),
        ),
      ],
      if (expanded) const Spacer() else const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => isGuestPreview ? _requireLogin(context) : _startChat(context),
          icon: Icon(isGuestPreview ? Icons.lock_outline : Icons.chat_bubble_outline),
          label: Text(
            isGuestPreview ? 'Accedi per contattare' : 'Contatta',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: content,
      ),
    );
  }

  void _requireLogin(BuildContext context) {
    Navigator.of(context).pop();
    openAuthScreen(context, initialMessage: 'Accedi per contattare il fornitore');
  }

  Future<void> _startChat(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final userId = AppScope.of(context).currentUserId;
    final listingRef = listing;

    Navigator.of(context).pop(); // chiude il dialog dettaglio

    void showError(String message) {
      final messenger = ScaffoldMessenger.maybeOf(rootNav.context);
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }

    if (userId == null) {
      showError('Devi essere autenticato');
      return;
    }

    try {
      final channel = await StreamChatService.instance.openListingChat(
        listing: listingRef,
        currentUserId: userId,
      );
      if (!rootNav.mounted) return;
      await rootNav.push(
        MaterialPageRoute(builder: (_) => ChannelPage(channel: channel)),
      );
    } catch (e, st) {
      debugPrint('Contatta failed: $e\n$st');
      final message = e is StateError
          ? e.message
          : 'Impossibile aprire la chat. Riprova.';
      showError(message);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textLightGrey, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: valueStyle ?? TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
