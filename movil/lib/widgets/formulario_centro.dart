import 'package:flutter/material.dart';

import '../modelos/cliente.dart';

/// Ventana para crear o editar un centro de trabajo: nombre, nº de cliente, CIF y dirección.
///
/// Devuelve los datos listos para enviar a la API, o null si se cancela.
Future<Map<String, dynamic>?> pedirDatosCentro(BuildContext context, {Centro? centro}) async {
  final nombre = TextEditingController(text: centro?.nombre);
  final codigo = TextEditingController(text: centro?.codigo);
  final cif = TextEditingController(text: centro?.cif);
  final direccion = TextEditingController(text: centro?.direccion);
  String? valor(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  final datos = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (contexto) {
      String? error;
      return StatefulBuilder(
        builder: (contexto, actualizar) => AlertDialog(
          title: Text(centro == null ? 'Nuevo centro de trabajo' : 'Datos del centro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  autofocus: centro == null,
                  decoration: InputDecoration(
                    labelText: 'Nombre del centro *',
                    hintText: 'Ej.: Nave de Inca',
                    prefixIcon: const Icon(Icons.store_outlined),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codigo,
                  decoration: const InputDecoration(labelText: 'Nº de cliente', prefixIcon: Icon(Icons.tag)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: cif,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'CIF / NIF', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: direccion,
                  decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.place_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (nombre.text.trim().isEmpty) {
                  actualizar(() => error = 'El nombre es obligatorio');
                  return;
                }
                Navigator.of(contexto).pop({
                  'nombre': nombre.text.trim(),
                  'codigo': valor(codigo),
                  'cif': valor(cif),
                  'direccion': valor(direccion),
                });
              },
              child: Text(centro == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      );
    },
  );
  return datos;
}
