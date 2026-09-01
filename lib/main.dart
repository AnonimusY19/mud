import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // just_audio non ha plugin nativo su Linux: serve media_kit.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    JustAudioMediaKit.ensureInitialized(linux: true, windows: false);
  }

  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'];
  final key = dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || url.isEmpty || key == null || key.isEmpty || key == 'your-anon-key-here') {
    throw StateError(
      'Configura SUPABASE_URL e SUPABASE_ANON_KEY in .env '
      '(copia da .env.example). Per un progetto cloud: Dashboard → Settings → API.',
    );
  }

  await Supabase.initialize(
    url: url,
    publishableKey: key,
  );

  final appState = AppState();
  await appState.loadThemePreference();

  runApp(MudApp(appState: appState));
}

class MudApp extends StatefulWidget {
  final AppState appState;

  const MudApp({super.key, required this.appState});

  @override
  State<MudApp> createState() => _MudAppState();
}

class _MudAppState extends State<MudApp> {
  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.appState,
      child: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          return MaterialApp(
            title: 'MUD',
            debugShowCheckedModeBanner: false,
            theme: buildMudTheme(Brightness.light),
            darkTheme: buildMudTheme(Brightness.dark),
            themeMode: widget.appState.themeMode,
            home: AppBootstrap(appState: widget.appState),
          );
        },
      ),
    );
  }
}
