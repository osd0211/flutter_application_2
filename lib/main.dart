import 'package:flutter/material.dart';

// Tema ve renkler
import 'ui/app_theme.dart';

// Ekranlar
import 'screens/scores_screen.dart';
import 'screens/players_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/leaderboard_screen.dart';

// Modeller (liderlik için)
import 'models.dart';

void main() => runApp(const EuroScoreApp());

/// ---------------------------------------------------------------------------
/// Paylaşılan store:
/// Tahmin ekranı (Challenges) buradaki listeyi güncelliyor,
/// Liderlik ekranı ise dinleyip anında güncelliyor.
/// ---------------------------------------------------------------------------
final ValueNotifier<List<PredictionChallenge>> challengeStore =
    ValueNotifier<List<PredictionChallenge>>(<PredictionChallenge>[]);

  class EuroScoreApp extends StatelessWidget {
    const EuroScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EuroScore',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.orange,
          secondary: AppColors.yellow,
          surface: AppColors.surface,
        ),
      ),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({super.key});

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Üst bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'EuroScore',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.yellow,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.sports_basketball, color: AppColors.yellow),
                ],
              ),
            ),
          ),
        ),
      ),

      // Gövde
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: IndexedStack(
          index: index,
          children: [
            const ScoresScreen(),
            const PlayersScreen(),
            ChallengesScreen(store: challengeStore),
            ValueListenableBuilder<List<PredictionChallenge>>(
              valueListenable: challengeStore,
              builder: (_, list, __) => LeaderboardScreen(challenges: list),
            ),
          ],
        ),
      ),

      // Alt navbar
      bottomNavigationBar: NavigationBar(
        height: 65,
        indicatorColor: AppColors.orange.withValues(alpha: .25),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.scoreboard), label: 'Skorlar'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Oyuncular'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Tahmin'),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Liderlik'),
        ],
      ),
    );
  }
}
