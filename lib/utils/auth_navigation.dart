import 'package:flutter/material.dart';
import '../screens/auth_screen.dart';
import '../theme/app_colors.dart';

Future<void> openAuthScreen(
  BuildContext context, {
  String? initialMessage,
  bool startOnRegister = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AuthScreen(
        initialMessage: initialMessage,
        startOnRegister: startOnRegister,
      ),
    ),
  );
}

void showLoginRequiredSnack(BuildContext context, {String? message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message ?? 'Accedi per usare questa funzione'),
      action: SnackBarAction(
        label: 'Accedi',
        textColor: AppColors.primary,
        onPressed: () => openAuthScreen(context),
      ),
    ),
  );
}
