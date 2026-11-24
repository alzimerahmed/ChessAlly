import 'package:flutter/material.dart';
import 'screens/play.dart';
import 'screens/coach.dart';
import 'screens/puzzles.dart';
import 'screens/theory.dart';
import 'screens/analysis.dart';
import 'screens/profile.dart';
import 'stats.dart';
import 'theme.dart';

void main() {
  runApp(const OpeningMasterApp());
}

class OpeningMasterApp extends StatelessWidget {
  const OpeningMasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Opening Master',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3B7A57), useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  Stats _stats = Stats();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadStats().then((s) => setState(() {
          _stats = s;
          _loaded = true;
          boardAppearance.value = BoardAppearance(
            theme: boardThemeById(s.boardTheme),
            pieces: pieceSetById(s.pieceSet),
          );
        }));
  }

  void _setStats(Stats s) => setState(() => _stats = s);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final screens = [
      PlayScreen(stats: _stats, setStats: _setStats),
      CoachScreen(stats: _stats, setStats: _setStats),
      PuzzlesScreen(stats: _stats, setStats: _setStats),
      TheoryScreen(stats: _stats, setStats: _setStats),
      const AnalysisScreen(),
      ProfileScreen(stats: _stats),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Opening Master')),
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_esports), label: 'Play'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.extension), label: 'Puzzles'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Theory'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
