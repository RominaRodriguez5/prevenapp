import 'package:flutter/material.dart';

import '../modelos/cliente.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../widgets/formulario_centro.dart';
import 'centro.dart';
import 'cliente_formulario.dart';

/// Carpeta de una sociedad: dentro están sus centros de trabajo, cada uno como una subcarpeta
/// (con su nº de cliente, CIF y dirección) y con lo que le falta y lo que tiene hecho.
/// Así queda un orden: sociedad → centros → actividades.
class ClientePantalla extends StatefulWidget {
  final int clienteId;

  const ClientePantalla({super.key, required this.clienteId});

  @override
  State<ClientePantalla> createState() => _ClientePantallaState();
}

class _ClientePantallaState extends State<ClientePantalla> {
  Cliente? _cliente;
  List<Centro> _centros = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final id = widget.clienteId;
      final cliente = await api.get('/clientes/$id') as Map<String, dynamic>;
      final centros = await api.get('/clientes/$id/centros') as List;
      setState(() {
        _cliente = Cliente.desdeJson(cliente);
        _centros = centros.map((c) => Centro.desdeJson(c as Map<String, dynamic>)).toList();
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _editar() async {
    final guardado = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (_) => ClienteFormularioPantalla(cliente: _cliente)),
    );
    if (guardado != null) {
      await _cargar();
      _avisar('Datos guardados');
    }
  }

  Future<void> _abrir(Centro centro) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CentroPantalla(cliente: _cliente!, centro: centro)),
    );
    _cargar();
  }

  Future<void> _nuevoCentro() async {
    final datos = await pedirDatosCentro(context);
    if (datos == null) return;
    try {
      await api.post('/clientes/${widget.clienteId}/centros', datos);
      await _cargar();
      _avisar('Centro "${datos['nombre']}" creado');
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _cliente;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Cabecera(
          sobretitulo: 'Sociedad',
          titulo: cliente?.nombre ?? 'Sociedad',
        ),
        actions: [
          if (cliente != null) IconButton(tooltip: 'Editar sociedad', onPressed: _editar, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
              : cliente == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              _centros.length == 1 ? '1 centro de trabajo' : '${_centros.length} centros de trabajo',
                              style: estiloSeccion,
                            ),
                          ),
                          for (final centro in _centros)
                            _Subcarpeta(centro: centro, alPulsar: () => _abrir(centro)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _nuevoCentro,
                              icon: const Icon(Icons.create_new_folder_outlined),
                              label: const Text('Nuevo centro'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: Icon(Icons.contact_page_outlined, color: Paleta.morado),
                                title: const Text('Datos de la sociedad', style: TextStyle(fontWeight: FontWeight.w800)),
                                childrenPadding: EdgeInsets.zero,
                                children: [_Datos(cliente: cliente)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

/// Subcarpeta de un centro de trabajo: nombre, nº de cliente, CIF, dirección y lo que le falta / tiene hecho.
/// Roja si tiene actividades de años anteriores sin hacer; verde si no le falta nada.
class _Subcarpeta extends StatelessWidget {
  final Centro centro;
  final VoidCallback alPulsar;

  const _Subcarpeta({required this.centro, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final atrasada = centro.atrasadas > 0;
    final alDia = centro.faltan == 0;
    final fondo = atrasada ? Paleta.rojoSuave : (alDia ? Paleta.verdeSuave : Paleta.blanco);
    final borde = atrasada ? Paleta.rojoBorde : (alDia ? Paleta.verde.withValues(alpha: 0.35) : Paleta.borde);
    final acento = atrasada ? Paleta.rojo : (alDia ? Paleta.verde : Paleta.morado);
    // "Nº 10234 · CIF B07000001"
    final identificacion = [
      if (centro.codigo != null && centro.codigo!.isNotEmpty) 'Nº ${centro.codigo}',
      if (centro.cif != null && centro.cif!.isNotEmpty) 'CIF ${centro.cif}',
    ].join(' · ');
    final String estado;
    if (alDia) {
      estado = 'Todo al día';
    } else if (atrasada) {
      estado = 'Faltan ${centro.faltan} · ${centro.atrasadas} ${centro.atrasadas == 1 ? 'atrasada' : 'atrasadas'}';
    } else {
      estado = 'Faltan ${centro.faltan}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borde, width: 1.2)),
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: acento, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(centro.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if (identificacion.isNotEmpty)
                        Text(
                          identificacion,
                          style: TextStyle(color: Paleta.tinta, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      if (centro.direccion != null && centro.direccion!.isNotEmpty)
                        Text(
                          centro.direccion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Paleta.tintaSuave, fontSize: 13),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '$estado  ·  ${centro.hechas} ${centro.hechas == 1 ? 'hecha' : 'hechas'}',
                        style: TextStyle(color: acento, fontWeight: FontWeight.w700, fontSize: 13),
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

/// Datos de contacto de la sociedad. Solo se muestran los que están rellenados.
/// (El nº de cliente, el CIF y la dirección están en cada centro.)
class _Datos extends StatelessWidget {
  final Cliente cliente;

  const _Datos({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final filas = <(IconData, String)>[
      if (cliente.telefono != null) (Icons.phone_outlined, cliente.telefono!),
      if (cliente.email != null) (Icons.alternate_email, cliente.email!),
      if (cliente.personaContacto != null) (Icons.person_outline, cliente.personaContacto!),
      if (cliente.notas != null) (Icons.notes, cliente.notas!),
    ];
    if (filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text('Sin datos de contacto. Pulsa ✏️ arriba para añadirlos.', style: TextStyle(color: Paleta.tintaSuave)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final (icono, texto) in filas)
            ListTile(
              dense: true,
              leading: Icon(icono, color: Paleta.tinta),
              title: SelectableText(texto, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
