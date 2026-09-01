import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import 'listing_detail_dialog.dart';
import 'type_badge.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  final bool isGuestPreview;

  const ListingCard({
    super.key,
    required this.listing,
    this.isGuestPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final place = listing.address.displayCity;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => ListingDetailDialog.open(
          context,
          listing,
          isGuestPreview: isGuestPreview,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      listing.imageUrl != null
                          ? Image.network(
                              listing.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => _placeholder(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(color: AppColors.surfaceGrey);
                              },
                            )
                          : _placeholder(),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: TypeBadge(type: listing.type),
                      ),
                      if (isGuestPreview)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Preview',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.category,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textLightGrey, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGuestPreview
                            ? 'Azienda verificata · Accedi per i dettagli'
                            : (listing.displayCompanyName.isNotEmpty
                                ? listing.displayCompanyName
                                : listing.description),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textLightGrey, fontSize: 11.5, height: 1.25),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: isGuestPreview
                                        ? '€${listing.price.toStringAsFixed(0)}…'
                                        : '€${listing.price.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13.5),
                                  ),
                                  if (!isGuestPreview)
                                    TextSpan(
                                      text: '/${listing.unit}',
                                      style: TextStyle(color: AppColors.textLightGrey, fontSize: 11),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined, size: 12, color: AppColors.textLightGrey),
                              const SizedBox(width: 2),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 90),
                                child: Text(
                                  place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: AppColors.textGrey, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.greenBg,
      alignment: Alignment.center,
      child: const Icon(Icons.sell_outlined, color: AppColors.green, size: 28),
    );
  }
}

