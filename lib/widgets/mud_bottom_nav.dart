import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class MudBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const MudBottomNav({super.key, required this.index, required this.onTap});

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(Icons.campaign_outlined, Icons.campaign, 'Annunci'),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Ordini'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
    _NavItem(Icons.person_outline, Icons.person, 'Profilo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == index;
              final color = selected ? AppColors.primary : AppColors.textLightGrey;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selected ? item.activeIcon : item.icon, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}