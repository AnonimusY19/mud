import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../main_shell.dart';
import '../services/stream_chat_service.dart';
import '../theme/app_colors.dart';

/// Gate di avvio: guest marketplace oppure sessione autenticata.
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
      await StreamChatService.instance.disconnect();
      widget.appState.clearSessionData();
      // Guest: carica comunque gli annunci pubblici.
      unawaited(widget.appState.loadListings());
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
      final profile = await widget.appState.loadProfile();
      try {
        await StreamChatService.instance.connect(profile);
      } catch (e) {
        debugPrint('Stream Chat connect error');
      }
      if (!mounted) return;
      if (_bootstrappingUserId != userId) return;
      _bootstrapInFlight = false;
      setState(() {
        _loading = false;
        _ready = true;
      });
    } catch (_) {
      _bootstrappingUserId = null;
      _bootstrapInFlight = false;
      await StreamChatService.instance.disconnect();
      widget.appState.clearSessionData();
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
              Text(
                'Caricamento...',
                style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    // Ospite: marketplace in sola lettura / preview.
    if (!_ready) {
      return const MainShell(isGuest: true);
    }

    final stream = StreamChatService.instance;
    if (stream.isReady) {
      return StreamChat(
        client: stream.client,
        themeData: StreamChatThemeData(),
        child: const MainShell(isGuest: false),
      );
    }

    return const MainShell(isGuest: false);
  }
}
