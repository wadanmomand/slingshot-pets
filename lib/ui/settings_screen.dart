// Settings screen: concept-style 3D toggles for music, SFX,
// vibration and notifications. Persisted in ProgressState.
import 'package:flutter/material.dart';

import '../art/sprites.dart';
import '../audio/sfx.dart';
import '../meta/progress.dart';
import 'chunky_text.dart';
import 'icon3d.dart';

class SettingsScreen extends StatefulWidget {
  final ProgressState progress;

  const SettingsScreen({super.key, required this.progress});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Sfx _sfx = Sfx();

  void _toggle(void Function() fn) {
    _sfx.click();
    setState(fn);
    widget.progress.save();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final bg = SpriteCache.instance.get('bg_map');
    return Scaffold(
      body: Stack(
        children: [
          // Garden background.
          Positioned.fill(
            child: bg != null
                ? RawImage(image: bg, fit: BoxFit.cover)
                : Container(color: const Color(0xFF7CB342)),
          ),
          SafeArea(
            child: Column(
              children: [
                // Back button.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
                    child: Icon3DButton(
                      spriteKey: 'btn3d_back',
                      size: 56,
                      onTap: () {
                        _sfx.click();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                // Chunky golden title (home-screen style).
                const ChunkyText('SETTINGS', fontSize: 104),
                const SizedBox(height: 16),
                // Cream panel with toggles.
                Container(
                  margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFDF5),
                          Color(0xFFFFF3D6)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: const Color(0xFFFFB300), width: 4),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black38,
                            blurRadius: 20,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _row(
                          spriteKey: 'btn3d_music',
                          label: 'Music',
                          value: p.music,
                          onTap: () => _toggle(() => p.music = !p.music),
                        ),
                        _row(
                          spriteKey: 'btn3d_sound',
                          label: 'Sound Effects',
                          value: p.sfxOn,
                          onTap: () => _toggle(() => p.sfxOn = !p.sfxOn),
                        ),
                        _row(
                          spriteKey: 'btn3d_vibrate',
                          label: 'Vibration',
                          value: p.vibration,
                          onTap: () =>
                              _toggle(() => p.vibration = !p.vibration),
                        ),
                        _row(
                          spriteKey: 'btn3d_bell',
                          label: 'Notifications',
                          value: p.notifications,
                          onTap: () => _toggle(
                              () => p.notifications = !p.notifications),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _goldBtn('SAVE', () {
                                _sfx.click();
                                p.save();
                                Navigator.pop(context);
                              }),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _goldBtn('RESET', () {
                                _sfx.click();
                                setState(() {
                                  p.music = true;
                                  p.sfxOn = true;
                                  p.vibration = false;
                                  p.notifications = true;
                                });
                                p.save();
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String spriteKey,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Icon3DRow(spriteKey: spriteKey),
          const SizedBox(width: 18),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8D5A00),
                    shadows: [
                      Shadow(
                          color: Color(0xFFFFE0B2),
                          offset: Offset(0, 2),
                          blurRadius: 0),
                    ])),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 132,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(37),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: value
                      ? const [
                          Color(0xFF4DD0E1),
                          Color(0xFF0097A7)
                        ]
                      : const [
                          Color(0xFFBDBDBD),
                          Color(0xFF9E9E9E)
                        ],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFE0E0E0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 5,
                          offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _goldBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3C4),
              Color(0xFFFFD54F),
              Color(0xFFFFB300),
              Color(0xFFF57C00),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
          border:
              Border.all(color: const Color(0xFF8D5A00), width: 3),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 5)),
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5D3A1A),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                        color: Color(0xFFFFF3C4),
                        offset: Offset(0, 2),
                        blurRadius: 0),
                  ])),
        ),
      ),
    );
  }
}
