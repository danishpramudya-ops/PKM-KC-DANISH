import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Visualisasi radar dekoratif untuk layar pindai node (Fase 1, migrasi
/// alur Connect — lihat home_shell.dart). Blip-nya TIDAK terikat posisi
/// node sungguhan: mesh tidak membawa data jarak/sudut, jadi radar ini
/// murni indikator "sedang aktif mencari", persis niat visual desain
/// Figma-nya (blip di sana juga dekoratif, bukan hasil kalkulasi bearing).
class RadarScanner extends StatelessWidget {
  final bool isScanning;
  final Animation<double> pulse;
  final double size;

  const RadarScanner({
    super.key,
    required this.isScanning,
    required this.pulse,
    this.size = 260,
  });

  static const _blipPositions = [
    Alignment(0.55, -0.6),
    Alignment(-0.7, 0.35),
    Alignment(0.75, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final ringColor = tokens.contentMuted.withValues(alpha: 0.25);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            _ring(size, ringColor),
            _ring(size * 0.66, ringColor),
            _ring(size * 0.33, ringColor),
            _crosshair(size, ringColor),
            if (isScanning) ..._blips(tokens),
            _focalPoint(tokens),
          ],
        ),
      ),
    );
  }

  Widget _ring(double diameter, Color color) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
      );

  Widget _crosshair(double diameter, Color color) => SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: diameter, height: 1, color: color),
            Container(width: 1, height: diameter, color: color),
          ],
        ),
      );

  List<Widget> _blips(AppTokens tokens) {
    return _blipPositions
        .map((align) => Align(
              alignment: align,
              child: Opacity(
                opacity: pulse.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.statusOk,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.statusOk.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ))
        .toList();
  }

  Widget _focalPoint(AppTokens tokens) => Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          border: Border.all(color: tokens.accent, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
      );
}
