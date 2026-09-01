import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../utils/auth_navigation.dart';
import 'app_logo.dart';

/// Header sito: hamburger · logo · Accedi/Registrati (o area utente).
class MudSiteHeader extends StatelessWidget {
  final VoidCallback onOpenMenu;
  final ValueChanged<int>? onSelectTab;
  final bool isGuest;

  const MudSiteHeader({
    super.key,
    required this.onOpenMenu,
    required this.isGuest,
    this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final email = AppScope.of(context).currentUserEmail;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onOpenMenu,
            icon: Icon(Icons.menu, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          const AppLogo(size: 34, borderRadius: 10),
          const SizedBox(width: 10),
          Text(
            'MUD',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'B2B MARKETPLACE',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Spacer(),
          if (isGuest) ...[
            TextButton(
              onPressed: () => openAuthScreen(context),
              child: const Text('Accedi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => openAuthScreen(context, startOnRegister: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Registrati', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            if (wide && email != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  email,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => onSelectTab?.call(4),
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Profilo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
