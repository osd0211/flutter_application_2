// lib/screens/scores_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_repository.dart';
import '../services/data_source.dart';
import '../ui/app_theme.dart';
import '../models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  bool _loading = true;
  List<DateTime> _days = <DateTime>[];

  /// Admin'in seçtiği "global" gün (settings.current_day_date)
  DateTime? _adminDay;

  @override
  void initState() {
    super.initState();
    _loadDays();
  }

  // CSV dosya isimlerinden günleri çıkar + DB'den admin gününü yükle
  Future<void> _loadDays() async {
    final assets = await DataSource.instance.listAllCsvAssets();
    final re = RegExp(r'boxscores_(\d{4})[-_](\d{2})[-_](\d{2})\.csv$');
    final parsed = <DateTime>[];

    for (final p in assets) {
      final m = re.firstMatch(p);
      if (m == null) continue;
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      parsed.add(DateTime(y, mo, d));
    }

    parsed.sort(); // eski -> yeni

    // DB'de daha önce kaydedilmiş admin günü var mı?
    final savedDay = await DatabaseService.loadCurrentDay();

    DateTime? dayToSelect;

    if (savedDay != null) {
      // listede aynı güne sahip bir DateTime bul
      try {
        dayToSelect = parsed.firstWhere(
          (d) =>
              d.year == savedDay.year &&
              d.month == savedDay.month &&
              d.day == savedDay.day,
        );
      } catch (_) {
        dayToSelect = null;
      }
    }

    // DB'de yoksa veya listedeki hiçbir günle eşleşmiyorsa: son günü seç
    if (dayToSelect == null && parsed.isNotEmpty) {
      dayToSelect = parsed.last;
      // default olarak DB'ye de yaz
      await DatabaseService.saveCurrentDay(dayToSelect);
    }

    if (!mounted) return;

    setState(() {
      _days = parsed;
      _loading = false;
      _adminDay = dayToSelect;
    });

    // GameRepository'ye ilk seçili günü yükle (herkes bu günle başlıyor)
    if (dayToSelect != null && mounted) {
      await context.read<GameRepository>().selectDay(dayToSelect);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<GameRepository>();
    final selected = repo.selectedDay;
    final phase = repo.simulationPhase;
    final role = context.watch<IAuthService>().currentUserRole;
    final isAdmin = role == 'admin';

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    // Henüz gün seçilmemişse (çok nadir)
    if (selected == null) {
      if (_days.isEmpty) {
        return const Center(
          child: Text(
            'Hiç CSV bulunamadı',
            style: TextStyle(color: Colors.white70),
          ),
        );
      }
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2340),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gün Seçin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButton<DateTime>(
                dropdownColor: const Color(0xFF0B1A2E),
                value: null,
                hint: const Text(
                  'Tarih seç',
                  style: TextStyle(color: Colors.white70),
                ),
                items: _days
                    .map(
                      (d) => DropdownMenuItem<DateTime>(
                        value: d,
                        child: Text(
                          _fmt(d),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (d) async {
                  if (d == null) return;
                  await context.read<GameRepository>().selectDay(d);
                  if (isAdmin) {
                    await DatabaseService.saveCurrentDay(d);
                    if (mounted) {
                      setState(() {
                        _adminDay = d;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Not: Geçen sezon verileri ekledikçe buradan seçim yapacaksınız.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Gün seçiliyse maçları getir
    final matches = repo.matchScoresForSelected();
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Bu gün için maç bulunamadı',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Admin gününü ve seçili günü kıyaslamak için date-only versiyon
    final DateTime? adminDay = _adminDay;
    final DateTime selDateOnly =
        DateTime(selected.year, selected.month, selected.day);
    DateTime? adminDateOnly;
    bool isBeforeAdmin = false;
    bool isAfterAdmin = false;

    if (adminDay != null) {
      adminDateOnly = DateTime(adminDay.year, adminDay.month, adminDay.day);
      isBeforeAdmin = selDateOnly.isBefore(adminDateOnly);
      isAfterAdmin = selDateOnly.isAfter(adminDateOnly);
    }

    return Column(
      children: [
        const SizedBox(height: 8),

        // Üstte seçili gün + herkes için gün değiştirme ikonu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Maç günü: ${_fmt(selected)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.calendar_month,
                  color: Colors.white70,
                  size: 20,
                ),
                tooltip: isAdmin
                    ? 'Global maç gününü değiştir (admin)'
                    : 'Günü değiştir (sadece görüntüleme)',
                onPressed: () async {
                  final picked = await showModalBottomSheet<DateTime>(
                    context: context,
                    backgroundColor: const Color(0xFF0B1A2E),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (_) => _DayPickerSheet(
                      days: _days,
                      fmt: _fmt,
                      initial: selected,
                    ),
                  );

                  if (picked == null) return;

                  await context.read<GameRepository>().selectDay(picked);

                  if (isAdmin) {
                    await DatabaseService.saveCurrentDay(picked);
                    if (mounted) {
                      setState(() {
                        _adminDay = picked;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
        if (isAdmin)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Not: Global maç gününü sadece admin değiştirir. Kullanıcılar günü sadece görüntülemek için değiştirebilir.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          ),

        // Simülasyon toggle SADECE ADMIN'de gözüksün
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Simülasyon Aşaması',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                ToggleButtons(
                  borderRadius: BorderRadius.circular(12),
                  isSelected: [
                    phase == SimulationPhase.notStarted,
                    phase == SimulationPhase.finished,
                  ],
                  constraints:
                      const BoxConstraints(minHeight: 36, minWidth: 90),
                  onPressed: (index) {
                    final newPhase = index == 0
                        ? SimulationPhase.notStarted
                        : SimulationPhase.finished;
                    context.read<GameRepository>().setSimulationPhase(newPhase);
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Maç Başlamadı'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Maç Bitti'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (isAdmin) const Divider(height: 1, color: Colors.white12),

        // Maç listesi
        Expanded(
          child: ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (_, i) {
              final m = matches[i];

              int homePts;
              int awayPts;

              if (adminDateOnly == null) {
                // Fallback: eski davranış
                homePts =
                    phase == SimulationPhase.notStarted ? 0 : m.homePts;
                awayPts =
                    phase == SimulationPhase.notStarted ? 0 : m.awayPts;
              } else if (isBeforeAdmin) {
                // Admin gününden ÖNCE: her zaman gerçek skorlar
                homePts = m.homePts;
                awayPts = m.awayPts;
              } else if (isAfterAdmin) {
                // Admin gününden SONRA: her zaman 0-0
                homePts = 0;
                awayPts = 0;
              } else {
                // Admin günü: toggle'a göre
                if (phase == SimulationPhase.notStarted) {
                  homePts = 0;
                  awayPts = 0;
                } else {
                  homePts = m.homePts;
                  awayPts = m.awayPts;
                }
              }

              return ListTile(
                title: Text(
                  '${m.home}  $homePts  —  $awayPts  ${m.away}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${m.tipoff.toLocal()}',
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

// ---------------------------------------------------------------------------
// Alt tarafta gün seçim sheet'i
// ---------------------------------------------------------------------------
class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({
    required this.days,
    required this.fmt,
    required this.initial,
  });

  final List<DateTime> days;
  final String Function(DateTime) fmt;
  final DateTime initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gün Seçin',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isSel = d.year == initial.year &&
                      d.month == initial.month &&
                      d.day == initial.day;
                  return ListTile(
                    title: Text(
                      fmt(d),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, color: Colors.white70)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop(d);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// OSD