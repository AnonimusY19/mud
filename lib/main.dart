import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'main_shell.dart';
import 'screens/auth_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final session = Supabase.instance.client.auth.currentSession;
            if (session == null) {
              return const AuthScreen();
            }
            return const MainShell();
          },
        ),
      ),
    );
  }
}
