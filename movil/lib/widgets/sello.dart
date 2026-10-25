import 'package:flutter/material.dart';

import '../tema.dart';

/// Confirmación de "actividad realizada": círculo con doble check,
/// "Todo al día en esta actividad" y la etiqueta "REALIZADA · fecha".
class Sello extends StatelessWidget {
  final String? fecha;
  final double escala; // se mantiene por compatibilidad

  const Sello({super.key, this.fecha, this.escala = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Paleta.lavandaSuave,
          child: Icon(Icons.done_all, size: 38, color: Paleta.morado),
        ),
        const SizedBox(height: 14),
        const Text('Todo al día en esta actividad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
        const SizedBox(height: 8),
        Pastilla(
          icono: Icons.check_circle_outline,
          texto: fecha == null ? 'REALIZADA' : 'REALIZADA · $fecha',
        ),
      ],
    );
  }
}

/// La misma confirmación, apareciendo con un pequeño rebote al hacer el check.
class SelloAnimado extends StatelessWidget {
  final String? fecha;

  const SelloAnimado({super.key, this.fecha});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, escala, hijo) => Opacity(
        opacity: ((escala - 0.6) / 0.4).clamp(0.0, 1.0),
        child: Transform.scale(scale: escala, child: hijo),
      ),
      child: Sello(fecha: fecha),
    );
  }
}
