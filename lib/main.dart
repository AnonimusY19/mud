import 'package:flutter/material.dart';
import 'app_state.dart';
import 'main_shell.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const MudApp());
}

class MudApp extends StatefulWidget {
  const MudApp({super.key});

  @override
  State<MudApp> createState() => _MudAppState();
}

class _MudAppState extends State<MudApp> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _appState,
      child: MaterialApp(
        title: 'MUD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        home: const MainShell(),
      ),
    );
  }
}