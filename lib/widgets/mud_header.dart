import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import 'mode_toggle.dart';

class MudHeader extends StatelessWidget {
  const MudHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          const Text('MUD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const Spacer(),
          ModeToggle(mode: appState.mode, onChanged: appState.setMode),
        ],
      ),
    );
  }
}