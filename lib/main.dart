import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'models.dart';
import 'services/game_repository.dart';
import 'services/auth_service.dart';
import 'services/prediction_repository.dart';
import 'ui/app_theme.dart';

import 'screens/scores_screen.dart';
import 'screens/players_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/database_service.dart';
import 'screens/profile_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await DatabaseService.generateUsernamesIfMissing();
  

  // Opsiyonel: gerçek auth kullanacaksan aktif bırak.
  if (Env.useSupabaseAuth) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
await DatabaseService.generateUsernamesIfMissing();

  runApp(const EuroScoreApp());
}

class EuroScoreApp extends StatelessWidget {
  const EuroScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Repository ve Auth’u uygulamaya enjekte ediyoruz.
  return MultiProvider(
  providers: [
    // ESKİ: Provider<GameRepository>.value(value: Env.games),
    ChangeNotifierProvider<GameRepository>.value(value: Env.games),

    Provider<PredictionRepository>.value(value: Env.predictions),
    ChangeNotifierProvider<IAuthService>.value(value: Env.auth),

  ],
  child: MaterialApp(
    title: 'EuroScore Demo',
    theme: AppTheme.theme,
    debugShowCheckedModeBanner: false,
    home: const AuthGate(),
    routes: {
      '/home': (_) => const _HomeShell(),
      '/login': (_) => const LoginScreen(),
    },
  ),
);
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<IAuthService>().currentUserId; // Env.auth yerine Provider
    if (uid == null) return const LoginScreen();
    return const _HomeShell();
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int index = 0;

  // In-memory store (tahminleri burada tutuyoruz)
  final List<PredictionChallenge> _store = <PredictionChallenge>[];

  // Liderlik için dinlenebilir liste
  final ValueNotifier<List<PredictionChallenge>> _challengesVN =
      ValueNotifier<List<PredictionChallenge>>(<PredictionChallenge>[]);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = <Widget>[
      const ScoresScreen(),
      const PlayersScreen(),

      // Tahmin ekranı: değişiklikleri Leaderboard’a aktar
      // Eğer ChallengesScreen(repo: ...) bekliyorsa aşağıdaki satırın
      // yorumunu açıp repo paramını ver:
      //
      // ChallengesScreen(
      //   store: _store,
      //   repo: context.read<PredictionRepository>(),
      //   onChanged: (list) {
      //     _challengesVN.value = List<PredictionChallenge>.unmodifiable(list);
      //   },
      // ),

      ChallengesScreen(
        store: _store,
        onChanged: (list) {
          _challengesVN.value = List<PredictionChallenge>.unmodifiable(list);
        },
      ),

      // Liderlik ekranı – ValueListenable bekler
      LeaderboardScreen(challenges: _challengesVN),

      const ProfileScreen(), 
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EuroScore'),
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () async {
              await context.read<IAuthService>().signOut();
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        height: 65,
        selectedIndex: index,
        indicatorColor: Colors.orange.withValues(alpha: .25),
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.scoreboard), label: 'Skorlar'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Oyuncular'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Tahmin'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Liderlik'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),

        ],
      ),
    );
  }
}
// OSD