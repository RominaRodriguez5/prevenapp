import 'package:flutter/material.dart';

import '../tema.dart';
import '../utilidades/turnos.dart';

/// Cuatro botones para elegir el turno de la formación: Mañana, Tarde, Extra mañana y Extra tarde.
class SelectorTurno extends StatelessWidget {
  final String valor;
  final ValueChanged<String> alCambiar;
  final DateTime fecha;

  const SelectorTurno({super.key, required this.valor, required this.alCambiar, required this.fecha});

  @override
  Widget build(BuildContext context) {
    Widget opcion(String turno) {
      final elegido = turno == valor;
      final extra = turno.startsWith('extra');
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: InkWell(
            onTap: () => alCambiar(turno),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: elegido ? Paleta.lavanda : Paleta.blanco,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: elegido ? Paleta.morado : Paleta.borde, width: elegido ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  Icon(
                    esDeTarde(turno) ? Icons.wb_twilight : Icons.wb_sunny_outlined,
                    color: elegido || extra ? Paleta.morado : Paleta.tinta,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nombresTurno[turno]!,
                    style: TextStyle(fontWeight: FontWeight.w700, color: elegido ? Paleta.morado : Paleta.tinta),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Turno', style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tintaSuave)),
        ),
        Row(children: [opcion('manana'), opcion('tarde')]),
        Row(children: [opcion('extra_manana'), opcion('extra_tarde')]),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            esFinDeSemana(fecha)
                ? 'Es fin de semana: se propone turno extra.'
                : 'Los turnos extra son los de fuera de lunes a viernes.',
            style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
          ),
        ),
      ],
    );
  }
}
