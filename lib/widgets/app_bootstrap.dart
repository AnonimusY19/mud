import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../main_shell.dart';
import '../screens/auth_screen.dart';
import '../theme/app_colors.dart';

/// Gate di avvio: sessione → profilo → app.
class AppBootstrap extends StatefulWidget {
  final AppState appState;

  const AppBootstrap({super.key, required this.appState});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  StreamSubscription<AuthState>? _authSub;
  bool _loading = true;
  bool _ready = false;
  bool _bootstrapInFlight = false;
  String? _authMessage;
  String? _bootstrappingUserId;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      unawaited(_onAuthChanged(event.session));
    });
    unawaited(_onAuthChanged(Supabase.instance.client.auth.currentSession));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(Session? session) async {
    if (session == null) {
      _bootstrappingUserId = null;
      _bootstrapInFlight = false;
      widget.appState.clearSessionData();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ready = false;
      });
      return;
    }

    final userId = session.user.id;
    if (_bootstrappingUserId == userId && (_ready || _bootstrapInFlight)) {
      return;
    }

    _bootstrappingUserId = userId;
    _bootstrapInFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _ready = false;
      });
    }

    try {
      await widget.appState.loadProfile();
      if (!mounted) return;
      if (_bootstrappingUserId != userId) return;
      _bootstrapInFlight = false;
      setState(() {
        _loading = false;
        _ready = true;
        _authMessage = null;
      });
    } catch (_) {
      _bootstrappingUserId = null;
      _bootstrapInFlight = false;
      widget.appState.clearSessionData();
      _authMessage = 'Impossibile accedere al profilo. Effettua di nuovo l\'accesso.';
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _ready = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Caricamento profilo...',
                style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
    }

    if (!_ready) {
      return AuthScreen(initialMessage: _authMessage);
    }

    return const MainShell();
  }
}
