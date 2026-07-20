// lib/screens/collect_screen.dart
// RenkliOkeyScout — Trainingsdaten sammeln
//
// Workflow pro Foto:
//   1. Foto vom Tisch / Rack machen (oder aus Galerie wählen)
//   2. Tippe auf einen Stein → unten Auswahl für Farbe + Zahl
//   3. "Speichern" → wandert nach Supabase
//
// Genutzt für das spätere TFLite-Modell (On-Device Erkennung).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/collect_service.dart';

class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key});

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  final _service = CollectService();
  final _picker = ImagePicker();

  File? _image;
  String? _gostergeColor; // which color the gösterge is (so we can match the joker)
  int? _gostergeNumber;
  final List<TileLabel> _labels = [];
  int? _selectedLabelIdx;
  bool _saving = false;
  int _totalSamples = 0;

  @override
  void initState() {
    super.initState();
    _service.totalSamples().then((v) {
      if (mounted) setState(() => _totalSamples = v);
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (x != null) {
        setState(() {
          _image = File(x.path);
          _labels.clear();
          _selectedLabelIdx = null;
          _gostergeColor = null;
          _gostergeNumber = null;
        });
      }
    } catch (e) {
      _snack('Kamera nicht verfügbar: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (x != null) {
        setState(() {
          _image = File(x.path);
          _labels.clear();
          _selectedLabelIdx = null;
          _gostergeColor = null;
          _gostergeNumber = null;
        });
      }
    } catch (e) {
      _snack('Galerie nicht verfügbar: $e');
    }
  }

  void _onImageTap(TapDownDetails details, BoxConstraints box) {
    if (_image == null) return;
    final dx = details.localPosition.dx / box.maxWidth;
    final dy = details.localPosition.dy / box.maxHeight;
    if (dx < 0 || dx > 1 || dy < 0 || dy > 1) return;
    setState(() {
      _labels.add(TileLabel(
        color: 'yellow',
        number: 1,
        isFalseOkey: false,
        x: dx - 0.05,
        y: dy - 0.05,
        w: 0.1,
        h: 0.1,
      ));
      _selectedLabelIdx = _labels.length - 1;
    });
  }

  void _updateLabel(int idx, {String? color, int? number, bool? isFalseOkey}) {
    setState(() {
      final old = _labels[idx];
      _labels[idx] = TileLabel(
        color: color ?? old.color,
        number: number ?? old.number,
        isFalseOkey: isFalseOkey ?? old.isFalseOkey,
        x: old.x,
        y: old.y,
        w: old.w,
        h: old.h,
      );
    });
  }

  void _deleteLabel(int idx) {
    setState(() {
      _labels.removeAt(idx);
      _selectedLabelIdx = null;
    });
  }

  Future<void> _save() async {
    if (_image == null || _labels.isEmpty) {
      _snack('Foto + mindestens 1 Stein nötig');
      return;
    }
    setState(() => _saving = true);
    final ok = await _service.uploadSample(
      imageFile: _image!,
      tiles: _labels,
      gostergeColor: _gostergeColor,
      gostergeNumber: _gostergeNumber,
    );
    setState(() => _saving = false);
    if (ok) {
      _snack('✅ Gespeichert! Total: ${_totalSamples + 1}');
      setState(() {
        _image = null;
        _labels.clear();
        _selectedLabelIdx = null;
        _gostergeColor = null;
        _gostergeNumber = null;
        _totalSamples++;
      });
    } else {
      _snack('❌ Upload fehlgeschlagen');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Trainingsdaten sammeln',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$_totalSamples Fotos',
                style: const TextStyle(
                  color: Color(0xFFF0C000),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _image == null ? _buildEmpty() : _buildEditor(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library,
                size: 80, color: Color(0xFF58A6FF)),
            const SizedBox(height: 16),
            const Text(
              'Sammle Trainingsdaten',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mache Fotos von echten Okey-Steinen.\n'
              'Tippe danach auf jeden Stein und wähle Farbe + Zahl.\n'
              'Mindestens 300 Fotos nötig für ein gutes Modell.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Foto machen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.image),
                label: const Text('Aus Galerie'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF58A6FF),
                  side: const BorderSide(color: Color(0xFF58A6FF)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb, color: Color(0xFFF0C000), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Tipp: Verschiedene\nLichtverhältnisse + Tische',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // Image with overlay
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            return GestureDetector(
              onTapDown: (d) => _onImageTap(d, box),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(_image!, fit: BoxFit.contain),
                  ),
                  // Existing bounding boxes
                  ...List.generate(_labels.length, (i) {
                    final t = _labels[i];
                    final selected = i == _selectedLabelIdx;
                    return Positioned(
                      left: t.x * box.maxWidth,
                      top: t.y * box.maxHeight,
                      width: t.w * box.maxWidth,
                      height: t.h * box.maxHeight,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedLabelIdx = i),
                        onLongPress: () => _deleteLabel(i),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFF0C000)
                                  : const Color(0xFF238636),
                              width: selected ? 3 : 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_colorEmoji(t.color)} ${t.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Counter top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_labels.length} Steine markiert',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const Divider(color: Color(0xFF30363D), height: 1),
        // Editor panel
        _buildEditorPanel(),
      ],
    );
  }

  Widget _buildEditorPanel() {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gösterge row (optional)
            Row(
              children: [
                const Text('Gösterge:',
                    style: TextStyle(
                        color: Color(0xFF8B949E), fontSize: 12)),
                const SizedBox(width: 8),
                _miniChip('Gelb', const Color(0xFFF0C000),
                    _gostergeColor == 'yellow',
                    () => setState(() => _gostergeColor = 'yellow')),
                _miniChip('Blau', const Color(0xFF58A6FF),
                    _gostergeColor == 'blue',
                    () => setState(() => _gostergeColor = 'blue')),
                _miniChip('Rot', const Color(0xFFDA3633),
                    _gostergeColor == 'red',
                    () => setState(() => _gostergeColor = 'red')),
                _miniChip('Schwarz', const Color(0xFF8B949E),
                    _gostergeColor == 'black',
                    () => setState(() => _gostergeColor = 'black')),
                const Spacer(),
                if (_gostergeColor != null)
                  DropdownButton<int>(
                    value: _gostergeNumber,
                    hint: const Text('Zahl',
                        style: TextStyle(color: Color(0xFF8B949E))),
                    dropdownColor: const Color(0xFF21262D),
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(13, (i) => i + 1)
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text('$n'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _gostergeNumber = v),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Editor for selected label
            if (_selectedLabelIdx != null) ...[
              const Divider(color: Color(0xFF30363D), height: 16),
              Row(
                children: [
                  Text(
                    'Ausgewählt: #${_selectedLabelIdx! + 1}',
                    style: const TextStyle(
                      color: Color(0xFFF0C000),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFDA3633)),
                    onPressed: () => _deleteLabel(_selectedLabelIdx!),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _colorBtn('yellow', const Color(0xFFF0C000), 'Gelb'),
                  _colorBtn('blue', const Color(0xFF58A6FF), 'Blau'),
                  _colorBtn('red', const Color(0xFFDA3633), 'Rot'),
                  _colorBtn('black', const Color(0xFF8B949E), 'Schwarz'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: List.generate(13, (i) {
                  final n = i + 1;
                  final selected = _labels[_selectedLabelIdx!].number == n;
                  return _numberChip(n, selected);
                }),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Checkbox(
                    value: _labels[_selectedLabelIdx!].isFalseOkey,
                    onChanged: (v) => _updateLabel(_selectedLabelIdx!,
                        isFalseOkey: v ?? false),
                    activeColor: const Color(0xFF238636),
                  ),
                  const Text('Sahte Okey (falscher Joker)',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Save button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _image = null;
                              _labels.clear();
                              _selectedLabelIdx = null;
                            }),
                    icon: const Icon(Icons.close),
                    label: const Text('Verwerfen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDA3633),
                      side: const BorderSide(color: Color(0xFFDA3633)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_saving ? 'Lädt hoch...' : 'Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _miniChip(
      String label, Color color, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorBtn(String color, Color hex, String label) {
    final selected = _selectedLabelIdx != null &&
        _labels[_selectedLabelIdx!].color == color;
    return GestureDetector(
      onTap: () => _updateLabel(_selectedLabelIdx!, color: color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? hex.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hex, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: hex,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _numberChip(int n, bool selected) {
    return GestureDetector(
      onTap: () => _updateLabel(_selectedLabelIdx!, number: n),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0C000)
              : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '$n',
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _colorEmoji(String color) {
    switch (color) {
      case 'blue':
        return '🟦';
      case 'red':
        return '🟥';
      case 'black':
        return '⬛';
      default:
        return '🟨';
    }
  }
}
