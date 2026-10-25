import 'dart:async';

import 'package:flutter/material.dart';

import '../modelos/cliente.dart';
import '../servicios/api.dart';
import '../tema.dart';
import 'cliente.dart';
import 'cliente_formulario.dart';

/// Sociedades del técnico como carpetas, con buscador y botón para dar de alta una nueva.
/// Cada carpeta dice cuántos centros tiene y cuántas actividades le faltan y tiene hechas.
class ClientesPantalla extends StatefulWidget {
  const ClientesPantalla({super.key});

  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> {
  final _buscador = TextEditingController();
  Timer? _espera;
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final texto = Uri.encodeQueryComponent(_buscador.text.trim());
      final lista = await api.get(texto.isEmpty ? '/clientes' : '/clientes?buscar=$texto') as List;
      setState(() {
        _clientes = lista.map((c) => Cliente.desdeJson(c as Map<String, dynamic>)).toList();
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Busca medio segundo después de dejar de escribir (no en cada letra).
  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 500), _cargar);
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (_) => const ClienteFormularioPantalla()),
    );
    if (creado == null) return;
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sociedad "${creado.nombre}" creada')));
  }

  Future<void> _abrir(Cliente cliente) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientePantalla(clienteId: cliente.id)));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              TextField(
                controller: _buscador,
                onChanged: _alEscribir,
                decoration: const InputDecoration(hintText: 'Sociedad, centro, nº de cliente o CIF', prefixIcon: Icon(Icons.search)),
              ),
              if (_cargando) const LinearProgressIndicator() else const SizedBox(height: 4),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!)
              else if (!_cargando && _clientes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _buscador.text.isEmpty
                        ? 'Todavía no tienes clientes.\nPulsa "Nueva sociedad" para añadir la primera.'
                        : 'No hay ninguna sociedad que coincida.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Paleta.tintaSuave, fontSize: 16),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '${_clientes.length} ${_clientes.length == 1 ? 'sociedad' : 'sociedades'}',
                    style: TextStyle(color: Paleta.tintaSuave),
                  ),
                ),
                // Carpetas en cuadrícula: 2 por fila en el móvil, 3 si hay sitio
                LayoutBuilder(
                  builder: (context, limites) {
                    const separacion = 12.0;
                    final columnas = limites.maxWidth >= 520 ? 3 : 2;
                    final ancho = (limites.maxWidth - separacion * (columnas - 1)) / columnas;
                    return Wrap(
                      spacing: separacion,
                      runSpacing: separacion,
                      children: [
                        for (final cliente in _clientes)
                          SizedBox(width: ancho, child: _Carpeta(cliente: cliente, alPulsar: () => _abrir(cliente))),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'nuevo-cliente',
            onPressed: _nuevo,
            icon: const Icon(Icons.add),
            label: const Text('Nueva sociedad', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Carpeta de una sociedad: pestaña arriba a la izquierda, nº de centros, nombre y contadores.
/// Roja si tiene actividades de años anteriores sin hacer; verde si no le falta nada.
class _Carpeta extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback alPulsar;

  const _Carpeta({required this.cliente, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final atrasada = cliente.atrasadas > 0;
    final alDia = cliente.faltan == 0;
    final fondo = atrasada ? Paleta.rojoSuave : (alDia ? Paleta.verdeSuave : Paleta.lavandaSuave);
    final pestana = atrasada ? Paleta.rojoBorde : (alDia ? Paleta.verde.withValues(alpha: 0.35) : Paleta.lavanda);
    final acento = atrasada ? Paleta.rojo : (alDia ? Paleta.verde : Paleta.morado);
    final String estado;
    if (alDia) {
      estado = 'Todo al día';
    } else if (atrasada) {
      estado = 'Faltan ${cliente.faltan} · ${cliente.atrasadas} ${cliente.atrasadas == 1 ? 'atrasada' : 'atrasadas'}';
    } else {
      estado = 'Faltan ${cliente.faltan}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La pestaña de la carpeta
        Container(
          width: 64,
          height: 12,
          decoration: BoxDecoration(
            color: pestana,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
        Material(
          color: fondo,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            side: BorderSide(color: pestana, width: 1.5),
          ),
          child: InkWell(
            onTap: alPulsar,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 18, color: acento),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cliente.numCentros} ${cliente.numCentros == 1 ? 'centro' : 'centros'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: acento, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        cliente.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Paleta.tinta, height: 1.2),
                      ),
                    ),
                    Text(
                      estado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: acento, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cliente.hechas} ${cliente.hechas == 1 ? 'hecha' : 'hechas'}',
                      style: TextStyle(color: Paleta.tintaSuave, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
