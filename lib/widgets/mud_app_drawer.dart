import 'package:flutter/material.dart';
import '../app_state.dart';
import '../screens/notifications_screen.dart';
import '../screens/pricing_screen.dart';
import '../theme/app_colors.dart';
import '../utils/auth_navigation.dart';
import 'app_logo.dart';

class MudAppDrawer extends StatelessWidget {
  final bool isGuest;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const MudAppDrawer({
    super.key,
    required this.isGuest,
    required this.currentIndex,
    required this.onSelect,
  });

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final isDark = appState.isDarkTheme;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  const AppLogo(size: 40, borderRadius: 10),
                  const SizedBox(width: 12),
                  Text(
                    'MUD',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.border),
            _item(context, Icons.home_outlined, 'Home / Annunci', 0),
            _item(context, Icons.inventory_2_outlined, 'I miei annunci', 1, requiresAuth: true),
            _item(context, Icons.receipt_long_outlined, 'Ordini', 2, requiresAuth: true),
            _item(context, Icons.chat_bubble_outline, 'Chat', 3, requiresAuth: true),
            _item(context, Icons.person_outline, 'Profilo', 4, requiresAuth: true),
            Divider(color: AppColors.border),
            ListTile(
              leading: Icon(Icons.payments_outlined, color: AppColors.textGrey),
              title: Text('Prezzi', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => _open(context, const PricingScreen()),
            ),
            ListTile(
              leading: Icon(Icons.notifications_outlined, color: AppColors.textGrey),
              title: Text('Notifiche', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                if (isGuest) {
                  Navigator.pop(context);
                  showLoginRequiredSnack(context, message: 'Accedi per vedere le notifiche');
                  openAuthScreen(context);
                  return;
                }
                _open(context, const NotificationsScreen());
              },
            ),
            Divider(color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'IMPOSTAZIONI',
                style: TextStyle(
                  color: AppColors.textLightGrey,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: AppColors.textGrey,
              ),
              title: Text(
                'Tema scuro',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isDark ? 'Attivo' : 'Tema chiaro attivo',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              value: isDark,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              onChanged: (dark) => appState.setDarkTheme(dark),
            ),
            if (isGuest) ...[
              Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.login, color: AppColors.primary),
                title: const Text(
                  'Accedi',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  openAuthScreen(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                title: const Text(
                  'Registrati',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  openAuthScreen(context, startOnRegister: true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    bool requiresAuth = false,
  }) {
    final selected = currentIndex == index;
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
      leading: Icon(icon, color: selected ? AppColors.primary : AppColors.textGrey),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (requiresAuth && isGuest) {
          showLoginRequiredSnack(context, message: 'Accedi per aprire "$label"');
          openAuthScreen(context);
          return;
        }
        onSelect(index);
      },
    );
  }
}
