import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';
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
          const AppLogo(size: 36, borderRadius: 10),
          const SizedBox(width: 10),
          const Text('MUD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const Spacer(),
          ModeToggle(mode: appState.mode, onChanged: appState.setMode),
        ],
      ),
    );
  }
}
