import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../tema.dart';
import '../utilidades/formato.dart';

/// Actividad en las listas filtradas de Inicio: roja si está atrasada, lavanda si está hecha, blanca si no.
class TarjetaActividadLista extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback alPulsar;

  const TarjetaActividadLista({super.key, required this.actividad, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final hecha = actividad.realizada;
    final atrasada = actividad.atrasada;
    final fondo = atrasada ? Paleta.rojoSuave : (hecha ? Paleta.lavandaSuave : Paleta.blanco);
    final borde = atrasada ? Paleta.rojoBorde : (hecha ? Colors.transparent : Paleta.borde);

    final String detalle;
    if (hecha && actividad.fechaRealizacion != null) {
      detalle = 'Realizada el ${fechaTexto(actividad.fechaRealizacion!)}'
          '${actividad.codigoPresupuesto == null ? '' : ' · ${actividad.codigoPresupuesto}'}';
    } else if (actividad.fechaProgramada != null) {
      detalle = 'Visita ${fechaTexto(actividad.fechaProgramada!)}'
          '${actividad.horaProgramada == null ? '' : ' · ${actividad.horaProgramada}'}';
    } else {
      detalle = atrasada ? 'Del contrato de ${actividad.anio}, sin fecha' : 'Sin fecha';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borde)),
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (atrasada) ...[
                        Pastilla.atrasada(texto: 'ATRASADA · ${actividad.anio}'),
                        const SizedBox(height: 8),
                      ],
                      Text(actividad.clienteYCentro, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(actividad.tipoNombre),
                      const SizedBox(height: 6),
                      Text(
                        detalle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hecha ? FontWeight.w700 : FontWeight.normal,
                          color: hecha ? Paleta.morado : Paleta.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: atrasada ? Paleta.rojo : Paleta.tintaSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
