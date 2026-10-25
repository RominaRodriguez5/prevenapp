import 'package:flutter/material.dart';

import '../servicios/api.dart';

/// Desplegable para elegir un técnico (captador o redactor).
///
/// La primera opción (valor null) es la opción por defecto, con el texto que se indique.
class SelectorTecnico extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final int? valor;
  final String? nombreValor; // por si el técnico elegido ya no está en la lista
  final String textoPorDefecto;
  final List<Tecnico> tecnicos;
  final ValueChanged<int?>? alCambiar;

  const SelectorTecnico({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    required this.textoPorDefecto,
    required this.tecnicos,
    required this.alCambiar,
    this.nombreValor,
  });

  @override
  Widget build(BuildContext context) {
    final opciones = [...tecnicos];
    final valor = this.valor;
    if (valor != null && !opciones.any((t) => t.id == valor)) {
      opciones.add(Tecnico(id: valor, nombre: nombreValor ?? 'Técnico $valor'));
    }
    final miId = api.usuario?.id;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: valor,
          isExpanded: true,
          onChanged: alCambiar,
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(textoPorDefecto, overflow: TextOverflow.ellipsis)),
            for (final tecnico in opciones)
              DropdownMenuItem<int?>(
                value: tecnico.id,
                child: Text(tecnico.id == miId ? '${tecnico.nombre} (yo)' : tecnico.nombre),
              ),
          ],
        ),
      ),
    );
  }
}
