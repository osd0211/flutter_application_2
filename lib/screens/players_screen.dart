// lib/screens/players_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../ui/app_theme.dart';
import '../models.dart';
import '../services/database_service.dart';

enum PlayerSortBy { points, assists, rebounds }

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen>
    with WidgetsBindingObserver {
  PlayerSortBy _sortBy = PlayerSortBy.points;

  /// Admin'in seçtiği global gün (settings.current_day_date)
  DateTime? _adminDay;
  bool _loadingAdminDay = true;

  /// selectedDay değişimini yakalamak için
  DateTime? _lastSelectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAdminDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App geri gelince (gir-çık yapınca) admin day'i tekrar DB'den al
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAdminDay();
    }
  }

  Future<void> _loadAdminDay() async {
    final day = await DatabaseService.loadCurrentDay();
    if (!mounted) return;
    setState(() {
      _adminDay = day;
      _loadingAdminDay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final day = repo.selectedDay;

    // ✅ selectedDay değişince adminDay'i DB'den tekrar çek (esas bug fix)
    if (day != null) {
      final current = DateTime(day.year, day.month, day.day);
      final last = _lastSelectedDay == null
          ? null
          : DateTime(
              _lastSelectedDay!.year,
              _lastSelectedDay!.month,
              _lastSelectedDay!.day,
            );

      if (last == null || current != last) {
        _lastSelectedDay = day;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // ekrana her rebuild'de spam olmasın diye yalnızca gün değişince çağırıyoruz
          _loadAdminDay();
        });
      }
    }

    if (day == null || _loadingAdminDay) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return _buildPlayers(repo, day);
  }

  Widget _buildPlayers(GameRepository repo, DateTime selectedDay) {
    final stats = repo.boxscoreForSelected(); // {playerId -> PlayerStat}
    final players = repo.playersForSelected(); // {playerId -> Player}
    final phase = repo.simulationPhase;

    // Admin günü ile seçili günü kıyaslayalım (date-only bazında)
    final adminDay = _adminDay;
    DateTime? adminDateOnly;
    bool isBeforeAdmin = false;
    bool isAfterAdmin = false;

    final selDateOnly =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    if (adminDay != null) {
      adminDateOnly = DateTime(adminDay.year, adminDay.month, adminDay.day);
      isBeforeAdmin = selDateOnly.isBefore(adminDateOnly);
      isAfterAdmin = selDateOnly.isAfter(adminDateOnly);
    }

    // Sadece gerçek oyuncular: players map'inde karşılığı olan id'ler
    final entries =
        stats.entries.where((e) => players[e.key] != null).toList();

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Oyuncu verisi yok',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Sıralama: her zaman gerçek istatistiğe göre (phase'den bağımsız)
    entries.sort((a, b) {
      final sa = a.value;
      final sb = b.value;
      switch (_sortBy) {
        case PlayerSortBy.points:
          return sb.pts.compareTo(sa.pts);
        case PlayerSortBy.assists:
          return sb.ast.compareTo(sa.ast);
        case PlayerSortBy.rebounds:
          return sb.reb.compareTo(sa.reb);
      }
    });

    return Column(
      children: [
        // Üstte sıralama seçici
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Sırala:',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                borderRadius: BorderRadius.circular(12),
                isSelected: [
                  _sortBy == PlayerSortBy.points,
                  _sortBy == PlayerSortBy.assists,
                  _sortBy == PlayerSortBy.rebounds,
                ],
                constraints:
                    const BoxConstraints(minHeight: 32, minWidth: 80),
                onPressed: (index) {
                  setState(() {
                    if (index == 0) {
                      _sortBy = PlayerSortBy.points;
                    } else if (index == 1) {
                      _sortBy = PlayerSortBy.assists;
                    } else {
                      _sortBy = PlayerSortBy.rebounds;
                    }
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Sayı'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Asist'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Ribaund'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Oyuncu listesi
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (_, i) {
              final playerId = entries[i].key;
              final s = entries[i].value;
              final player = players[playerId]!;

              final name = player.name.trim();

              // Gösterilecek istatistiği admin günü + phase'e göre belirleyelim
              int pts;
              int ast;
              int reb;

              if (adminDateOnly == null) {
                // Fallback: eski davranış (sadece phase'e göre)
                pts = phase == SimulationPhase.notStarted ? 0 : s.pts;
                ast = phase == SimulationPhase.notStarted ? 0 : s.ast;
                reb = phase == SimulationPhase.notStarted ? 0 : s.reb;
              } else if (isBeforeAdmin) {
                // Admin gününden ÖNCE: her zaman gerçek istatistik
                pts = s.pts;
                ast = s.ast;
                reb = s.reb;
              } else if (isAfterAdmin) {
                // Admin gününden SONRA: her zaman 0-0-0
                pts = 0;
                ast = 0;
                reb = 0;
              } else {
                // Admin günü: phase'e göre
                if (phase == SimulationPhase.notStarted) {
                  pts = 0;
                  ast = 0;
                  reb = 0;
                } else {
                  pts = s.pts;
                  ast = s.ast;
                  reb = s.reb;
                }
              }

              return ListTile(
                leading: const CircleAvatar(radius: 18),
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Sayı $pts • Asist $ast • Rib $reb',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
