import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'models.dart';
import 'services/prediction_repository.dart';

import 'ui/app_theme.dart';
import 'screens/scores_screen.dart';
import 'screens/players_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opsiyonel: gerçek auth kullanacaksan aktif bırak.
  if (Env.useSupabaseAuth) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const EuroScoreApp());
}

class EuroScoreApp extends StatelessWidget {
  const EuroScoreApp({super.key}); // İstersen {super.key} kalabilir; sorun yok.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EuroScore Demo',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/home': (_) => const _HomeShell(),
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock/gerçek auth’a göre giriş kontrolü
    final uid = Env.auth.currentUserId;
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

  // In-memory store + repo (mock veya gerçek)
  final List<PredictionChallenge> _store = <PredictionChallenge>[];
  final PredictionRepository _repo = Env.predictions;

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

      // Tahmin ekranı — değişiklik VN’ye yazılır
   ChallengesScreen(
  store: _store,
  onChanged: (list) {
    _challengesVN.value = List<PredictionChallenge>.unmodifiable(list);
  },
),

      // Liderlik ekranı — ValueListenable bekler
      LeaderboardScreen(challenges: _challengesVN),
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
              await Env.auth.signOut();
              if (!context.mounted) return;
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
        // SDK’n “withOpacity deprecated” uyarısı varsa withValues kullan.
        indicatorColor: Colors.orange.withValues(alpha: .25),
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.scoreboard), label: 'Skorlar'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Oyuncular'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Tahmin'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Liderlik'),
        ],
      ),
    );
  }
}
