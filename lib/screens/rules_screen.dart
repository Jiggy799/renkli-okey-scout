// lib/screens/rules_screen.dart
// RenkliOkeyScout — Komplettes Regelwerk

import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Regelwerk',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Farben & Tischfarbe ────────────────────────────────────────
              _section(
                title: '1. Tischfarbe & Gösterge',
                icon: Icons.palette,
                color: Color(0xFFF0C000),
                children: [
                  _text('Der Gösterge-Stein bestimmt die TISCHFARBE für diese Runde:'),
                  const SizedBox(height: 12),
                  _colorRow('Gelb', '2-fach', Color(0xFFF0C000)),
                  _colorRow('Blau', '3-fach', Color(0xFF1F6FEB)),
                  _colorRow('Rot', '4-fach', Color(0xFFDA3633)),
                  _colorRow('Schwarz', '5-fach', Color(0xFF6E7681)),
                  const SizedBox(height: 8),
                  _note('Die Tischfarbe multipliziert alle Strafpunkte.'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Joker / Okey ───────────────────────────────────────────────
              _section(
                title: '2. Joker (Okey)',
                icon: Icons.star,
                color: Color(0xFFF0C000),
                children: [
                  _text('Der Joker ist immer der Stein, der genau EINE ZAHL über dem Gösterge liegt, in DERSELBEN FARBE.'),
                  const SizedBox(height: 8),
                  _example('Gösterge Rot 5  →  Joker: Rot 6'),
                  _example('Gösterge Blau 13 →  Joker: Blau 1'),
                  const SizedBox(height: 12),
                  _bold('WYSIWYG-Regel:'),
                  _text('Die App berechnet EXAKT was auf dem Brett liegt. Der Spieler muss den Joker selbst richtig platzieren. Die App optimiert NIEMALS automatisch.'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Gültige Kombinationen ──────────────────────────────────────
              _section(
                title: '3. Gültige Kombinationen',
                icon: Icons.extension,
                color: Color(0xFF1F6FEB),
                children: [
                  _bold('Reihen (Serien)'),
                  _text('3+ aufeinanderfolgende Zahlen in derselben Farbe.'),
                  _example('Rot 3 – Rot 4 – Rot 5'),
                  _example('Schwarz 12 – Schwarz 13 – Schwarz 1  ✓'),
                  _warning('Schwarz 13 – Schwarz 1 – Schwarz 2  ✗  (13→1→2 verboten)'),
                  _note('Die 1 ist der ABSOLUTE STOPP!'),
                  const SizedBox(height: 12),
                  _bold('Joker als Platzhalter in Reihen'),
                  _text('Ein Joker (Okey) darf GENAU EINE Lücke in einer Reihe füllen.'),
                  _example('Rot 5 + Joker + Rot 7  ✓  (Joker = Rot 6)'),
                  _example('Rot 5 + Joker + Joker + Rot 8  ✗  (2 Joker = 2 Lücken)'),
                  _note('Joker werden in der Praxis als „falscher Okey" (Stern) auf dem Brett platziert.'),
                  const SizedBox(height: 12),
                  _bold('Gruppen'),
                  _text('Mindestens 3 Steine mit derselben Zahl, aber unterschiedlichen Farben.'),
                  _example('Gelb 8 + Blau 8 + Schwarz 8'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Çifte ─────────────────────────────────────────────────────
              _section(
                title: '4. Çifte-Regel',
                icon: Icons.copy,
                color: Color(0xFFDA3633),
                children: [
                  _text('Will ein Spieler mit ÇIFTE gewinnen, gibt es ZWEI gültige Blatt-Varianten:'),
                  const SizedBox(height: 8),
                  _bold('Variante 1 — 7 Doppel-Paare'),
                  _bullet('Alle 14 Steine bestehen aus genau 7 Paaren'),
                  _bullet('Ein Paar = 2× gleiche Zahl UND gleiche Farbe (z.B. Rot 3 + Rot 3)'),
                  _bullet('Das ergibt 0 Schrott-Steine'),
                  _example('Rot 3 + Rot 3, Blau 7 + Blau 7, ...'),
                  const SizedBox(height: 8),
                  _bold('Variante 2 — 5 Paare + 4er-Reihe'),
                  _bullet('Genau 5 Paare (gleiche Zahl + gleiche Farbe)'),
                  _bullet('Die restlichen 4 Steine MÜSSEN eine Reihe in derselben Farbe bilden'),
                  _example('Rot 8, Rot 9, Rot 10, Rot 11'),
                  _note('Joker zählt als Platzhalter in der 4er-Reihe (eine Lücke erlaubt).'),
                  _warning('Joker können NICHT in Paaren verwendet werden!'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Foto-Pflicht ──────────────────────────────────────────────
              _section(
                title: '5. Foto-Pflicht',
                icon: Icons.camera_alt,
                color: Color(0xFF238636),
                children: [
                  _text('Am Ende jeder Runde müssen ALLE Spieler — auch der Gewinner — ein Foto ihres Brettes machen.'),
                  const SizedBox(height: 8),
                  _penaltyRow('Kein Foto', '+100 Strafpunkte'),
                ],
              ),
              const SizedBox(height: 16),

              // ── System A ──────────────────────────────────────────────────
              _section(
                title: '6. Punktesystem A — Runden-Strafpunkte',
                icon: Icons.calculate,
                color: Color(0xFF58A6FF),
                children: [
                  _text('Für Verlierer am Ende jeder Runde:'),
                  const SizedBox(height: 8),
                  _bold('Schritt 1: Summe der "Schrott-Steine"'),
                  _text('Alle Steine die NICHT in gültigen Reihen/Gruppen liegen, werden addiert.'),
                  const SizedBox(height: 8),
                  _bold('Schritt 2: × Tischfarbe'),
                  _example('Bei Rot (×4) und Summe 15 → 15 × 4 = 60 Punkte'),
                  const SizedBox(height: 8),
                  _bold('Schritt 3: Gewinner-Bonus'),
                  _winnerRow('Okey (Joker) abgelegt', '×2'),
                  _winnerRow('Çifte gewonnen', '×2'),
                  _winnerRow('Okey + Çifte', '×4 (kumuliert)'),
                  const SizedBox(height: 8),
                  _note('Beispiel: Rot ×4 + Joker Finish ×2 = ×8 für alle Verlierer!'),
                ],
              ),
              const SizedBox(height: 16),

              // ── System B ──────────────────────────────────────────────────
              _section(
                title: '7. Punktesystem B — Gösterge-Bonus',
                icon: Icons.card_giftcard,
                color: Color(0xFFF0C000),
                children: [
                  _text('Ein ZUSÄTZLICHES System das erst am Ende des Spiels (nach 11 Runden) abgerechnet wird.'),
                  const SizedBox(height: 8),
                  _bold('Wer zeigt den Gösterge vor?'),
                  _text('Zeigt ein Spieler direkt beim Austeilen den Gösterge, bekommt er Minuspunkte gutgeschrieben.'),
                  const SizedBox(height: 8),
                  _gostergeRow('Gelb', '−20'),
                  _gostergeRow('Blau', '−30'),
                  _gostergeRow('Rot', '−40'),
                  _gostergeRow('Schwarz', '−50'),
                  const SizedBox(height: 8),
                  _bold('Endabrechnung'),
                  _text('Nach Runde 11 werden alle gesammelten Minuspunkte von den Gesamt-Strafpunkten abgezogen.'),
                  _warning('Es ist möglich, mit der Gesamtpunktzahl ins MINUS zu kommen!'),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget Helpers ────────────────────────────────────────────────────────

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: color.withValues(alpha: 0.2), height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
  );

  Widget _bold(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 4),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _note(String t) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: 12, color: Color(0xFF58A6FF)),
        SizedBox(width: 6),
        Expanded(
          child: Text(t, style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12, fontStyle: FontStyle.italic)),
        ),
      ],
    ),
  );

  Widget _warning(String t) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(Icons.warning_amber, size: 12, color: Color(0xFFDA3633)),
        SizedBox(width: 6),
        Expanded(
          child: Text(t, style: TextStyle(color: Color(0xFFDA3633), fontSize: 12, fontStyle: FontStyle.italic)),
        ),
      ],
    ),
  );

  Widget _example(String t) => Padding(
    padding: const EdgeInsets.only(left: 12, top: 2),
    child: Row(
      children: [
        Text('  › ', style: TextStyle(color: Color(0xFF6E7681), fontSize: 13)),
        Expanded(
          child: Text(t, style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: Color(0xFFF0C000), fontSize: 13)),
        Expanded(
          child: Text(t, style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _colorRow(String name, String mult, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text('×$mult', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _gostergeRow(String color, String pts) {
    final col = color == 'Gelb' ? Color(0xFFF0C000)
        : color == 'Blau' ? Color(0xFF1F6FEB)
        : color == 'Rot' ? Color(0xFFDA3633)
        : Color(0xFF6E7681);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(color, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          Text(pts, style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _penaltyRow(String label, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFF8B949E)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Color(0xFFDA3633).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Color(0xFFDA3633)),
            ),
            child: Text(pts, style: TextStyle(color: Color(0xFFDA3633), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _winnerRow(String label, String mult) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.emoji_events, size: 12, color: Color(0xFFF0C000)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Color(0xFFF0C000).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(mult, style: TextStyle(color: Color(0xFFF0C000), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
