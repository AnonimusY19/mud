import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import 'type_badge.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: listing.imageUrl != null
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
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TypeBadge(type: listing.type),
                      Flexible(
                        child: Text(
                          listing.category,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textLightGrey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '€${listing.price.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            TextSpan(
                              text: '/${listing.unit}',
                              style: const TextStyle(color: AppColors.textLightGrey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLightGrey),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                listing.location,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.greenBg,
      alignment: Alignment.center,
      child: const Icon(Icons.sell_outlined, color: AppColors.green, size: 36),
    );
  }
}