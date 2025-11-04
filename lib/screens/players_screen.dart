import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../models.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  List<Player> data = allPlayersToday();
  String sort = 'PTS';

  void _sortBy(String key) {
    setState(() {
      sort = key;
      switch (key) {
        case 'REB':
          data.sort((a,b) => b.reb.compareTo(a.reb));
          break;
        case 'AST':
          data.sort((a,b) => b.ast.compareTo(a.ast));
          break;
        default:
          data.sort((a,b) => b.pts.compareTo(a.pts));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _sortBy('PTS');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          PopupMenuButton<String>(
            initialValue: sort,
            onSelected: _sortBy,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'PTS', child: Text('Sort by PTS')),
              PopupMenuItem(value: 'REB', child: Text('Sort by REB')),
              PopupMenuItem(value: 'AST', child: Text('Sort by AST')),
            ],
          )
        ],
      ),
      body: ListView.separated(
        itemCount: data.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = data[i];
          return ListTile(
            title: Text('${p.name} • ${p.team}'),
            subtitle: Text('PTS ${p.pts.toStringAsFixed(1)}  •  REB ${p.reb.toStringAsFixed(1)}  •  AST ${p.ast.toStringAsFixed(1)}'),
          );
        },
      ),
    );
  }
}
