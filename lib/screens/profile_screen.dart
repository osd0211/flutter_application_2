// lib/screens/profile_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'admin_users_screen.dart';
import '../core/badges.dart';

class _TeamNameRange {
  final String fromSeason;
  final String toSeason;
  final String name;

  const _TeamNameRange(this.fromSeason, this.toSeason, this.name);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;

  // ✅ DB’den okunan user bilgileri (auth cache yerine)
  String? _dbName;
  String? _dbEmail;
  String? _dbRole;
  String? _dbUsername;
  int _dbLevel = 1;
  int _dbXp = 0;

  String? _favoriteTeamCode;
  String? _favoriteTeamName;

  String? _favoritePlayerId;
  String? _favoritePlayerName;

  Map<String, List<_TeamNameRange>> _historyByCode = {};
  Map<String, String> _playerIdToName = {};

  // ✅ rozetler
  List<Map<String, Object?>> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadProfileFromDb();

    _buildTeamNameHistoryFromHeader().then((m) {
      if (!mounted) return;
      setState(() => _historyByCode = m);
    });

    _loadLatestPlayersFromPlayersCsv().then((m) {
      if (!mounted) return;
      setState(() => _playerIdToName = m);
    });
  }

  Future<void> _loadProfileFromDb() async {
    final auth = context.read<IAuthService>();
    final uid = auth.currentUserId;

    if (uid == null) {
      setState(() {
        _dbName = null;
        _dbEmail = null;
        _dbRole = null;
        _dbUsername = null;
        _dbLevel = 1;
        _dbXp = 0;

        _favoriteTeamCode = null;
        _favoriteTeamName = null;
        _favoritePlayerId = null;
        _favoritePlayerName = null;
        _badges = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final row = await DatabaseService.getUserById(uid);
    final badges = await DatabaseService.loadBadgesForUser(uid);

    setState(() {
      _dbName = row?['name'] as String?;
      _dbEmail = row?['email'] as String?;
      _dbRole = row?['role'] as String?;
      _dbUsername = row?['username'] as String?;
      _dbLevel = (row?['level'] as int?) ?? 1;
      _dbXp = (row?['xp'] as int?) ?? 0;

      _favoriteTeamCode = row?['favorite_team_code'] as String?;
      _favoriteTeamName = row?['favorite_team_name'] as String?;
      _favoritePlayerId = row?['favorite_player_id'] as String?;
      _favoritePlayerName = row?['favorite_player_name'] as String?;

      _badges = badges;
      _loading = false;
    });
  }

  // ------------------------------------------------------------
  // ✅ CSV parser (quote destekli)
  // ------------------------------------------------------------
  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }

      if (ch == ',' && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    out.add(sb.toString());
    return out;
  }

  // ------------------------------------------------------------
  // ✅ Header’dan code -> name (son görülen isim)
  // ------------------------------------------------------------
  Future<Map<String, String>> _loadTeamCodeToNameFromHeader() async {
    final csv = await rootBundle.loadString('data_raw/euroleague_header.csv');
    final lines = const LineSplitter().convert(csv);
    if (lines.length < 2) return {};

    final headers = _parseCsvLine(lines.first)
        .map((e) => e.replaceAll('"', '').trim().toLowerCase())
        .toList();

    int idx(String col) => headers.indexOf(col);

    final idxAId = idx('team_id_a');
    final idxBId = idx('team_id_b');
    final idxAName = idx('team_a');
    final idxBName = idx('team_b');

    if ([idxAId, idxBId, idxAName, idxBName].any((i) => i == -1)) return {};

    final map = <String, String>{};

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final v = _parseCsvLine(line);

      void put(int idIdx, int nameIdx) {
        if (idIdx >= v.length || nameIdx >= v.length) return;
        final code = v[idIdx].replaceAll('"', '').trim();
        final name = v[nameIdx].replaceAll('"', '').trim();
        if (code.isNotEmpty && name.isNotEmpty) {
          map[code] = name;
        }
      }

      put(idxAId, idxAName);
      put(idxBId, idxBName);
    }

    return map;
  }

  int _seasonNum(String seasonCode) {
    final s = seasonCode.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? 0;
  }

  // ------------------------------------------------------------
  // ✅ Takım isim tarihçesi
  // ------------------------------------------------------------
  Future<Map<String, List<_TeamNameRange>>> _buildTeamNameHistoryFromHeader() async {
    final csv = await rootBundle.loadString('data_raw/euroleague_header.csv');
    final lines = const LineSplitter().convert(csv);
    if (lines.length < 2) return {};

    final headers = _parseCsvLine(lines.first)
        .map((e) => e.replaceAll('"', '').trim().toLowerCase())
        .toList();

    int idx(String col) => headers.indexOf(col);

    final idxSeason = idx('season_code');
    final idxAId = idx('team_id_a');
    final idxBId = idx('team_id_b');
    final idxAName = idx('team_a');
    final idxBName = idx('team_b');

    if ([idxSeason, idxAId, idxBId, idxAName, idxBName].any((i) => i == -1)) {
      return {};
    }

    // code -> season -> name
    final Map<String, Map<String, String>> raw = {};

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final v = _parseCsvLine(line);

      final season =
          (idxSeason < v.length) ? v[idxSeason].replaceAll('"', '').trim() : '';
      if (season.isEmpty) continue;

      void put(int idIdx, int nameIdx) {
        if (idIdx >= v.length || nameIdx >= v.length) return;
        final code = v[idIdx].replaceAll('"', '').trim();
        final name = v[nameIdx].replaceAll('"', '').trim();
        if (code.isEmpty || name.isEmpty) return;

        raw.putIfAbsent(code, () => {});
        raw[code]!.putIfAbsent(season, () => name);
      }

      put(idxAId, idxAName);
      put(idxBId, idxBName);
    }

    final Map<String, List<_TeamNameRange>> history = {};

    raw.forEach((code, seasonToName) {
      final seasons = seasonToName.keys.toList()
        ..sort((a, b) => _seasonNum(a).compareTo(_seasonNum(b)));

      _TeamNameRange? current;

      for (final s in seasons) {
        final name = seasonToName[s]!;
        if (current == null) {
          current = _TeamNameRange(s, s, name);
        } else if (current.name == name) {
          current = _TeamNameRange(current.fromSeason, s, current.name);
        } else {
          history.putIfAbsent(code, () => []).add(current);
          current = _TeamNameRange(s, s, name);
        }
      }

      if (current != null) {
        history.putIfAbsent(code, () => []).add(current);
      }
    });

    return history;
  }

  // ------------------------------------------------------------
  // ✅ Oyuncu CSV -> (player_id -> player_name) sadece SON SEZON
  // ------------------------------------------------------------
  int _seasonNumFromE(String seasonCode) {
    final digits = seasonCode.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<Map<String, String>> _loadLatestPlayersFromPlayersCsv() async {
    final csv = await rootBundle.loadString('data_raw/euroleague_players.csv');
    final lines = const LineSplitter().convert(csv);
    if (lines.length < 2) return {};

    final headers = _parseCsvLine(lines.first)
        .map((e) => e.replaceAll('"', '').trim().toLowerCase())
        .toList();

    int idx(String col) => headers.indexOf(col);

    final idxSeason = idx('season_code');
    final idxPlayerId = idx('player_id');
    final idxPlayerName = idx('player');

    if ([idxSeason, idxPlayerId, idxPlayerName].any((i) => i == -1)) return {};

    final Map<String, int> bestSeasonById = {};
    final Map<String, String> bestNameById = {};

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final v = _parseCsvLine(line);

      if (idxSeason >= v.length || idxPlayerId >= v.length || idxPlayerName >= v.length) {
        continue;
      }

      final seasonCode = v[idxSeason].replaceAll('"', '').trim();
      final pid = v[idxPlayerId].replaceAll('"', '').trim();
      final name = v[idxPlayerName].replaceAll('"', '').trim();

      if (seasonCode.isEmpty || pid.isEmpty || name.isEmpty) continue;

      final sn = _seasonNumFromE(seasonCode);
      final prev = bestSeasonById[pid];

      if (prev == null || sn > prev) {
        bestSeasonById[pid] = sn;
        bestNameById[pid] = name;
      }
    }

    return bestNameById;
  }

  // ------------------------------------------------------------
  // ✅ Favori takım seç
  // ------------------------------------------------------------
  Future<void> _showPickFavoriteTeamDialog(BuildContext context) async {
    final auth = context.read<IAuthService>();
    final uid = auth.currentUserId;
    if (uid == null) return;

    Map<String, String> codeToName;
    try {
      codeToName = await _loadTeamCodeToNameFromHeader();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takım listesi yüklenemedi (header.csv)')),
      );
      return;
    }

    if (codeToName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takım bulunamadı. header.csv kontrol et.')),
      );
      return;
    }

    final entries = codeToName.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final selectedCode = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String query = '';
        final ctrl = TextEditingController();

        List<MapEntry<String, String>> filtered() {
          final q = query.trim().toLowerCase();
          if (q.isEmpty) return entries;
          return entries
              .where((e) =>
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q))
              .toList();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final list = filtered();
            return AlertDialog(
              title: const Text('Favori Takım Seç'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Takım ara...',
                      ),
                      onChanged: (v) => setLocal(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = list[i];
                          final isSelected = e.key == _favoriteTeamCode;

                          return ListTile(
                            title: Text(e.value),
                            subtitle: Text(e.key),
                            trailing: isSelected ? const Icon(Icons.check) : null,
                            onTap: () => Navigator.pop(ctx, e.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''), // temizle
                  child: const Text('Temizle'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedCode == null) return;

    final String? newCode = selectedCode.trim().isEmpty ? null : selectedCode.trim();
    final String? newName = (newCode == null) ? null : codeToName[newCode];

    await DatabaseService.updateFavoriteTeam(
      userId: uid,
      teamCode: newCode,
      teamName: newName,
    );

    await _loadProfileFromDb();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newCode == null ? 'Favori takım temizlendi' : 'Favori takım kaydedildi ✅ (Badge)',
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ✅ Favori oyuncu seç
  // ------------------------------------------------------------
  Future<void> _showPickFavoritePlayerDialog(BuildContext context) async {
    final auth = context.read<IAuthService>();
    final uid = auth.currentUserId;
    if (uid == null) return;

    Map<String, String> idToName = _playerIdToName;

    if (idToName.isEmpty) {
      try {
        idToName = await _loadLatestPlayersFromPlayersCsv();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oyuncu listesi yüklenemedi (players.csv)')),
        );
        return;
      }
    }

    if (idToName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyuncu bulunamadı. CSV yolu/kolonları kontrol et.')),
      );
      return;
    }

    final entries = idToName.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final selectedId = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String query = '';
        final ctrl = TextEditingController();

        List<MapEntry<String, String>> filtered() {
          final q = query.trim().toLowerCase();
          if (q.isEmpty) return entries;
          return entries
              .where((e) =>
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q))
              .toList();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final list = filtered();
            return AlertDialog(
              title: const Text('Favori Oyuncu Seç'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Oyuncu ara...',
                      ),
                      onChanged: (v) => setLocal(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = list[i];
                          final isSelected = e.key == _favoritePlayerId;

                          return ListTile(
                            title: Text(e.value),
                            trailing: isSelected ? const Icon(Icons.check) : null,
                            onTap: () => Navigator.pop(ctx, e.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Temizle'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedId == null) return;

    final String? newId = selectedId.trim().isEmpty ? null : selectedId.trim();
    final String? newName = (newId == null) ? null : idToName[newId];

    await DatabaseService.updateFavoritePlayer(
      userId: uid,
      playerId: newId,
      playerName: newName,
    );

    await _loadProfileFromDb();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newId == null ? 'Favori oyuncu temizlendi' : 'Favori oyuncu kaydedildi ✅ (Badge)',
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ✅ Username edit
  // ------------------------------------------------------------
  Future<void> _showEditUsernameDialog(
    BuildContext context, {
    required int userId,
    required String currentUsername,
    required int level,
    required bool isAdmin,
  }) async {
    if (!isAdmin && level < 5) return;

    final ctrl =
        TextEditingController(text: currentUsername == '-' ? '' : currentUsername);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı adını değiştir'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Yeni kullanıcı adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final newUsername = result.trim();
    if (newUsername.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı boş olamaz')),
      );
      return;
    }

    try {
      await DatabaseService.adminUpdateUsername(
        userId: userId,
        newUsername: newUsername,
      );

      await _loadProfileFromDb();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username güncellendi ✅')),
      );
    } catch (e) {
      if (!context.mounted) return;

      final msg = e.toString().contains('username-already-exists')
          ? 'Bu kullanıcı adı alınmış.'
          : e.toString().contains('username-empty')
              ? 'Kullanıcı adı boş olamaz.'
              : 'Güncelleme sırasında hata oluştu.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ------------------------------------------------------------
  // ✅ Change Password (dialog)
  // ------------------------------------------------------------
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final auth = context.read<IAuthService>();
    final uid = auth.currentUserId;
    if (uid == null) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final new2Ctrl = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;
    bool obscure3 = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Şifre Değiştir'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: 'Mevcut şifre',
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure1 = !obscure1),
                          icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: 'Yeni şifre (min 6)',
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure2 = !obscure2),
                          icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: new2Ctrl,
                      obscureText: obscure3,
                      decoration: InputDecoration(
                        labelText: 'Yeni şifre (tekrar)',
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure3 = !obscure3),
                          icon: Icon(obscure3 ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final current = currentCtrl.text;
    final next = newCtrl.text;
    final next2 = new2Ctrl.text;

    if (next != next2) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni şifreler eşleşmiyor')),
      );
      return;
    }

    try {
      await DatabaseService.changePassword(
        userId: uid,
        currentPassword: current,
        newPassword: next,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre güncellendi ✅')),
      );
    } catch (e) {
      if (!context.mounted) return;

      final s = e.toString();
      final msg = s.contains('wrong-password')
          ? 'Mevcut şifre yanlış.'
          : s.contains('weak-password')
              ? 'Yeni şifre en az 6 karakter olmalı.'
              : s.contains('user-not-found')
                  ? 'Kullanıcı bulunamadı.'
                  : 'Şifre güncellenirken hata oluştu.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<IAuthService>();
    final userId = auth.currentUserId ?? -1;

    final name = _dbName ?? auth.currentUserName ?? '-';
    final username = _dbUsername ?? auth.currentUsername ?? '-';
    final email = _dbEmail ?? auth.currentUserEmail ?? '-';
    final role = _dbRole ?? auth.currentUserRole ?? '-';

    final level = _dbLevel;
    final xp = _dbXp;

    final isAdmin = (role == 'admin');

    final List<_TeamNameRange> ranges =
        (_favoriteTeamCode == null) ? const [] : (_historyByCode[_favoriteTeamCode!] ?? const []);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileFromDb,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Profil',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // PROFILE CARD
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _row('Kullanıcı adı', username),
                          const Divider(height: 24),
                          _row('İsim', name),
                          const Divider(height: 24),
                          _row('Email', email),
                          const Divider(height: 24),
                          _row('Rol', role),
                          const Divider(height: 24),
                          _row('Level', '$level'),
                          const Divider(height: 24),
                          _row('XP', '$xp'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ ROZETLER
if (_badges.isNotEmpty) ...[
  Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rozetlerim',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _badges.map((b) {
              final key = (b['badge_key'] as String?) ?? '';
              final earnedAt = (b['earned_at'] as String?) ?? '';
              final meta = badgeCatalog[key];

              final title = meta?.title ?? key;
              final icon = meta?.icon ?? Icons.verified;
              final xp = DatabaseService.xpForBadge(key);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (key.isEmpty) return;
                  showBadgeDetailsSheet(
                    context,
                    badgeKey: key,
                    earnedAt: earnedAt,
                    xp: xp,
                  );
                },
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ),
  ),
  const SizedBox(height: 12),
],


                  // FAVORITE TEAM
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.star_outline),
                      title: const Text('Favori Takım'),
                      subtitle: Text(_favoriteTeamName ?? 'Henüz seçilmedi'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showPickFavoriteTeamDialog(context),
                    ),
                  ),

                  // TEAM NAME HISTORY
                  if (_favoriteTeamCode != null && ranges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Takım İsim Tarihçesi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            ...ranges.map((r) {
                              final from = _seasonNum(r.fromSeason);
                              final to = _seasonNum(r.toSeason);
                              final years = (from == to) ? '$from' : '$from–$to';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text('• $years: ${r.name}'),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // FAVORITE PLAYER
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Favori Oyuncu'),
                      subtitle: Text(_favoritePlayerName ?? 'Henüz seçilmedi'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showPickFavoritePlayerDialog(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // USERNAME CHANGE
                  Card(
                    child: ListTile(
                      leading: Icon((isAdmin || level >= 5) ? Icons.edit : Icons.lock_outline),
                      title: const Text('Kullanıcı adı değiştirme'),
                      subtitle: Text(
                        isAdmin
                            ? 'Admin ✅ (level bağımsız)'
                            : (level >= 5 ? 'Açık ✅ (Level 5+)' : 'Kilitli 🔒 (Level 5’te açılır)'),
                      ),
                      trailing: (isAdmin || level >= 5)
                          ? const Icon(Icons.arrow_forward_ios, size: 16)
                          : const Icon(Icons.lock),
                      onTap: (isAdmin || level >= 5)
                          ? () => _showEditUsernameDialog(
                                context,
                                userId: userId,
                                currentUsername: username,
                                level: level,
                                isAdmin: isAdmin,
                              )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ CHANGE PASSWORD
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Şifre değiştirme'),
                      subtitle: const Text('Mevcut şifren ile yeni şifre belirle'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Nasıl level atlarım?'),
                      subtitle: Text('Tahmin yaptıkça ve badge kazandıkça XP kazanırsın.'),
                    ),
                  ),

                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Admin Panel'),
                        subtitle: const Text('Kullanıcıların username/level/xp düzenle (test)'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                          );
                          // ✅ admin panelden dönünce tekrar DB’den çek
                          if (!mounted) return;
                          await _loadProfileFromDb();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          flex: 6,
          child: Text(value, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
