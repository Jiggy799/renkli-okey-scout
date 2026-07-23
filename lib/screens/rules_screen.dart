// lib/screens/rules_screen.dart
// RenkliOkeyScout — Animierte Okey-Regeln (integriert, kein WebView)
// Aufruf: context.push('/rules');

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/score_calculator.dart';

// ─── Tile Widget ───────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final int number;
  final TileColor color;
  final bool isJoker;
  final double w, h;
  final bool highlight;

  const _Tile(this.number, this.color, {
    this.isJoker = false,
    this.w = 40, this.h = 54,
    this.highlight = false,
  });

  Color get _bg {
    switch (color) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF2D333B);
    }
  }
  Color get _text => color == TileColor.yellow ? Colors.black87 : Colors.white;

  @override
  Widget build(BuildContext ctx) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: w, height: h,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isJoker ? const Color(0xFFFFD700) : Colors.transparent,
          width: isJoker ? 2.5 : 1.5,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha:0.6), blurRadius: 12, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.Center,
        children: [
          Text(
            isJoker ? '⭐' : '$number',
            style: TextStyle(
              color: isJoker ? const Color(0xFFFFD700) : _text,
              fontWeight: FontWeight.bold,
              fontSize: w * 0.36,
            ),
          ),
          if (isJoker)
            Text('J', style: TextStyle(color: const Color(0xFFFFD700), fontSize: 7, fontWeight: FontWeight.bold))
          else
            Text(
              _colorName,
              style: TextStyle(color: _text.withValues(alpha:0.65), fontSize: 6.5),
            ),
        ],
      ),
    );
  }

  String get _colorName {
    switch (color) {
      case TileColor.yellow: return 'Gelb';
      case TileColor.blue:   return 'Blau';
      case TileColor.red:    return 'Rot';
      case TileColor.black:  return 'Schwarz';
    }
  }
}

// ─── InfoBox ─────────────────────────────────────────────────────────────────

class _Box extends StatelessWidget {
  final String title;
  final Color? borderColor;
  final Widget child;
  final EdgeInsets padding;

  const _Box({required this.title, this.borderColor, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

// ─── Page Data ────────────────────────────────────────────────────────────────

class _Page {
  final String tag;
  final String title;
  final Widget body;
  const _Page(this.tag, this.title, this.body);
}

final _pages = <_Page>[
  // ── 0: Ziel ──
  _Page('Willkommen', '🎯 Das Ziel',
    _Box(
      title: '',
      child: Column(
        children: [
          const Text(
            'Weniger Minuspunkte = besser.\nAlle starten bei 0.\nAm Ende hat der Gewinner die wenigsten Punkte.',
            style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 15, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _rankBadge('🥇', '0', 'Gewinner', const Color(0xFF3FB950)),
              _rankBadge('🥈', '24', 'Platz 2', const Color(0xFF58A6FF)),
              _rankBadge('🥉', '91', 'Platz 3', const Color(0xFFF85149)),
            ],
          ),
        ],
      ),
    ),
  ),

  // ── 1: Farben ──
  _Page('Schritt 1', 'Die 4 Farben',
    Column(children: [
      const _Box(
        title: '',
        child: Text(
          'Jede Farbe hat einen Multiplikator.\nSchrott × Farbwert = Basisstrafe',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _factorBadge(TileColor.yellow, 2),
          _factorBadge(TileColor.blue,   3),
          _factorBadge(TileColor.red,    4),
          _factorBadge(TileColor.black,  5),
        ],
      ),
    ]),
  ),

  // ── 2: Reihen ──
  _Page('Schritt 2', 'Gültige Reihen',
    Column(children: [
      const _Box(
        title: 'Was ist eine Reihe?',
        child: Text(
          '3+ Steine derselben Farbe in Zahlenfolge.\n12 → 13 → 1 ist OK! (Corner-Wrap)',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, height: 1.5),
        ),
      ),
      const SizedBox(height: 12),
      _tileRow([_Tile(4, TileColor.yellow), _Tile(5, TileColor.yellow), _Tile(6, TileColor.yellow)]),
      const SizedBox(height: 6),
      _tileRow([_Tile(10, TileColor.blue), _Tile(11, TileColor.blue), _Tile(12, TileColor.blue), _Tile(13, TileColor.blue), _Tile(1, TileColor.blue)]),
      const SizedBox(height: 4),
      const Text('⟳  12 → 13 → 1 ist ERLAUBT', style: TextStyle(color: Color(0xFF3FB950), fontSize: 12)),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tile(13, TileColor.red, w: 32, h: 44),
          const SizedBox(width: 4),
          _Tile(1, TileColor.red, w: 32, h: 44),
          const SizedBox(width: 4),
          _Tile(2, TileColor.red, w: 32, h: 44),
        ],
      ),
      const SizedBox(height: 4),
      const Text('13 → 1 → 2 ist VERBOTEN!', style: TextStyle(color: Color(0xFFF85149), fontSize: 12)),
    ]),
  ),

  // ── 3: Joker ──
  _Page('Schritt 3', 'Der Joker',
    Column(children: [
      const _Box(
        title: 'Was ist der Joker?',
        child: Text(
          'Joker = Gösterge + 1\nGösterge = 7 → Joker = 8\nGösterge = 13 → Joker = 1 (Wrap!)',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, height: 1.6),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFD700), style: BorderStyle.solid, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            const Text('Gösterge = Gelb 7', style: TextStyle(color: Color(0xFFF0C000), fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Tile(7, TileColor.yellow),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Color(0xFF8B949E), size: 18),
                const SizedBox(width: 8),
                _Tile(8, TileColor.yellow, isJoker: true),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const _Box(
        title: '⭐ Sahte Okey (Stern)',
        child: Text(
          'Der Stern-Stein ist der "falsche Joker".\nEr occupies die gleiche Position wie der echte Joker.',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.5),
        ),
      ),
    ]),
  ),

  // ── 4: Joker in Reihen ──
  _Page('Schritt 4', 'Joker in Reihen',
    Column(children: [
      const _Box(
        title: 'Joker füllt EXAKT EINE Lücke',
        child: Text(
          '• Ein Joker in einer Reihe: ✅\n• Zwei Joker: ❌\n• Joker muss echte Lücke füllen',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.6),
        ),
      ),
      const SizedBox(height: 12),
      _tileRow([_Tile(4, TileColor.yellow), _Tile(5, TileColor.yellow, isJoker: true), _Tile(6, TileColor.yellow)]),
      const SizedBox(height: 6),
      const Text('✅ 4 – ⭐ – 6', style: TextStyle(color: Color(0xFF3FB950), fontSize: 13)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tile(7, TileColor.black, w: 32, h: 44),
          _Tile(8, TileColor.black, isJoker: true, w: 32, h: 44),
          _Tile(7, TileColor.black, w: 32, h: 44),
        ],
      ),
      const SizedBox(height: 6),
      const Text('Zwei Joker = ❌', style: TextStyle(color: Color(0xFFF85149), fontSize: 13)),
    ]),
  ),

  // ── 5: Çifte ──
  _Page('Schritt 5', 'Çifte — Zwei Wege zu gewinnen',
    Column(children: [
      _Box(
        title: 'Variante 1: 7 Doppel-Paare',
        borderColor: const Color(0xFF3FB950),
        child: const Text(
          'Exakt 7 Paare (alle 14 Steine).\nKein Joker erlaubt.\n→ 0 Minuspunkte',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.5),
        ),
      ),
      const SizedBox(height: 10),
      _Box(
        title: 'Variante 2: 5 Paare + 4er-Serie',
        borderColor: const Color(0xFFD29922),
        child: const Text(
          '5 Paare + 1 Reihe von genau 4 Steinen.\nJoker IN der Reihe erlaubt!\n→ 0 Minuspunkte',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.5),
        ),
      ),
    ]),
  ),

  // ── 6: Strafpunkte ──
  _Page('Schritt 6', 'Strafpunkte berechnen',
    Column(children: [
      const _Box(
        title: '',
        child: Text(
          'Schrott-Steine × Tischfarbe × Joker × Çifte',
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Schrott-Steine:        6', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontFamily: 'Courier')),
            Text('× Tischfarbe (Rot):    × 4', style: TextStyle(color: Color(0xFF3FB950), fontSize: 13, fontFamily: 'Courier')),
            Text('Zwischenergebnis:      = 24', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, fontFamily: 'Courier')),
            Text('× Joker-Finish:        × 2', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontFamily: 'Courier')),
            Text('─' * 28, style: TextStyle(color: Color(0xFF30363D))),
            Text('= 48 Minuspunkte!', style: TextStyle(color: Color(0xFFF85149), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Table(
        border: TableBorder(
          horizontalInside: BorderSide.none,
          verticalInside: BorderSide.none,
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
        },
        children: const [
          TableRow(children: [Text('Situation', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)), Text('Faktor', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12))]),
          TableRow(children: [Text('Gelb', style: TextStyle(color: Color(0xFFF0C000), fontSize: 12)), Text('×2', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
          TableRow(children: [Text('Blau', style: TextStyle(color: const Color(0xFF1F6FEB), fontSize: 12)), Text('×3', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
          TableRow(children: [Text('Rot', style: TextStyle(color: const Color(0xFFDA3633), fontSize: 12)), Text('×4', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
          TableRow(children: [Text('Schwarz', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12)), Text('×5', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
          TableRow(children: [Text('+ Joker-Finish', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)), Text('×2', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
          TableRow(children: [Text('+ Çifte', style: TextStyle(color: Color(0xFFD29922), fontSize: 12)), Text('×2', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 12))]),
        ],
      ),
    ]),
  ),

  // ── 7: Maximum ──
  _Page('Schritt 7', '🔥 Maximum ×20',
    Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
        ),
        child: Column(
          children: [
            const Text('Schwarz × Joker × Çifte', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
            const SizedBox(height: 8),
            Text('6 × 20 = 120 Minuspunkte!', style: TextStyle(color: const Color(0xFFF85149), fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _factorBadge(TileColor.black, 5),
          const Text('×', style: TextStyle(fontSize: 24, color: Color(0xFFFFD700))),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFD700), width: 2), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('⭐×2', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold))),
          ),
          const Text('×', style: TextStyle(fontSize: 24, color: Color(0xFFD29922))),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD29922), width: 2), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Ç×2', style: TextStyle(color: Color(0xFFD29922), fontSize: 18, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    ]),
  ),

  // ── 8: Gösterge ──
  _Page('Schritt 8', 'Gösterge zeigen',
    Column(children: [
      const _Box(
        title: '',
        child: Text(
          'Wenn du den exakten Gösterge-Stein hast,\nkannst du ihn zeigen.',
          style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 12),
      _Box(
        title: 'Variante A — Straf-Variante',
        borderColor: const Color(0xFFD29922),
        child: Column(children: [
          _tileRow([_Tile(7, TileColor.black, highlight: true)]),
          const SizedBox(height: 8),
          const Text('Du zeigst:  andere → +5 Punkte\nDu selbst: 0 Punkte', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 10),
      _Box(
        title: 'Variante B — Belohnungs-Variante',
        borderColor: const Color(0xFF3FB950),
        child: Column(children: [
          _tileRow([_Tile(7, TileColor.black, highlight: true)]),
          const SizedBox(height: 8),
          const Text('Du zeigst:  −5 Punkte\nAndere:      0 Punkte', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 10),
      const Text('Gesammelt über 11 Runden → am Ende abziehen',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
    ]),
  ),

  // ── 9: Foto ──
  _Page('Schritt 9', '⚠️ Foto-Pflicht',
    Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF85149), width: 2),
        ),
        child: Column(children: [
          const Text('⚠️ Foto-Pflicht', style: TextStyle(color: Color(0xFFF85149), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Kein Foto am Rundenende?', style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14)),
          const Text('+100 Minuspunkte!', style: TextStyle(color: Color(0xFFF85149), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(children: [
                const Text('📷', style: TextStyle(fontSize: 32)),
                const Text('Foto gemacht', style: TextStyle(color: Color(0xFF3FB950), fontSize: 12)),
                const Text('+0 Punkte', style: TextStyle(color: Color(0xFF3FB950), fontSize: 12)),
              ]),
              Column(children: [
                const Text('🚫📷', style: TextStyle(fontSize: 32)),
                const Text('Kein Foto', style: TextStyle(color: Color(0xFFF85149), fontSize: 12)),
                const Text('+100 Punkte!', style: TextStyle(color: Color(0xFFF85149), fontSize: 12)),
              ]),
            ],
          ),
        ]),
      ),
    ]),
  ),
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _rankBadge(String emoji, String pts, String label, Color color) {
  return Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 24)),
    Text(pts, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
  ]);
}

Widget _factorBadge(TileColor color, int val) {
  final bg = color == TileColor.yellow ? const Color(0xFFF0C000)
      : color == TileColor.blue   ? const Color(0xFF1F6FEB)
      : color == TileColor.red    ? const Color(0xFFDA3633)
      : const Color(0xFF2D333B);
  final name = color == TileColor.yellow ? 'Gelb'
      : color == TileColor.blue   ? 'Blau'
      : color == TileColor.red    ? 'Rot'
      : 'Schwarz';
  return Container(
    width: 70, padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF21262D),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: Column(children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 4),
      Text('×$val', style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 18, fontWeight: FontWeight.bold)),
      Text(name, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
    ]),
  );
}

Widget _tileRow(List<Widget> tiles) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: tiles.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: t)).toList(),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  int _page = 0;
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => _page = i);
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
        title: Text(
          _pages[_page].title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white54),
            onPressed: _page > 0 ? () => _go(_page - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white54),
            onPressed: _page < _pages.length - 1 ? () => _go(_page + 1) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) =>
                GestureDetector(
                  onTap: () => _go(i),
                  child: Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? const Color(0xFF58A6FF)
                          : i < _page  ? const Color(0xFF3FB950)
                          : const Color(0xFF30363D),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (ctx, i) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_pages[i].tag.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F6FEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_pages[i].tag, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 14),
                    _pages[i].body,
                  ],
                ),
              ),
            ),
          ),
          // Navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC9D1D9),
                      side: const BorderSide(color: Color(0xFF30363D)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _page > 0 ? () => _go(_page - 1) : null,
                    child: const Text('← Zurück'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _page < _pages.length - 1
                        ? () => _go(_page + 1)
                        : () => context.pop(),
                    child: Text(_page < _pages.length - 1 ? 'Weiter →' : 'Fertig ✓'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
