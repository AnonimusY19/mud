import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import 'type_badge.dart';

class MyListingTile extends StatelessWidget {
  final Listing listing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MyListingTile({super.key, required this.listing, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isVendo = listing.type == 'Vendo';
    final barColor = isVendo ? AppColors.green : AppColors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeBadge(type: listing.type),
                    const SizedBox(height: 8),
                    Text(listing.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '€${listing.price.toStringAsFixed(2)}/${listing.unit} · ${listing.category}',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textGrey), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}