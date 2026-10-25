import 'package:flutter/material.dart';

import '../tema.dart';

/// Franja de rayas amarillas y negras, como la cinta de "zona de peligro".
/// Se usa en el borde de las actividades atrasadas.
class CintaBaliza extends StatelessWidget {
  final double ancho;

  const CintaBaliza({super.key, this.ancho = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: ancho, child: CustomPaint(painter: _RayasPainter()));
  }
}

class _RayasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Paleta.baliza);
    final negro = Paint()..color = Paleta.tinta;
    const separacion = 16.0;
    // Rayas diagonales cada 16 píxeles
    for (double y = -size.width; y < size.height + size.width; y += separacion) {
      final raya = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y - size.width)
        ..lineTo(size.width, y - size.width + separacion / 2)
        ..lineTo(0, y + separacion / 2)
        ..close();
      canvas.drawPath(raya, negro);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
