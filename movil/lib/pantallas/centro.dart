import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../modelos/cliente.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';
import '../utilidades/mapas.dart';
import '../widgets/formulario_centro.dart';
import 'actividad.dart';

/// Carpeta de un centro de trabajo (dentro de la carpeta del cliente): lo que le falta por
/// hacer y lo que ya está hecho, ordenado por años. Más abajo, plegados, la dirección del
/// centro y las actividades de su contrato.
class CentroPantalla extends StatefulWidget {
  final Cliente cliente;
  final Centro centro;

  const CentroPantalla({super.key, required this.cliente, required this.centro});

  @override
  State<CentroPantalla> createState() => _CentroPantallaState();
}

class _CentroPantallaState extends State<CentroPantalla> {
  late Centro _centro = widget.centro;
  bool _cargado = false;
  List<LineaContrato> _contrato = [];
  List<Actividad> _actividades = [];
  List<TipoActividad> _tipos = [];
  bool _verHechas = false; // false = le faltan, true = hechas
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final id = widget.cliente.id;
      final centroId = _centro.id;
      final centros = await api.get('/clientes/$id/centros') as List;
      final contrato = await api.get('/clientes/$id/obligatorias?centro_id=$centroId') as List;
      final actividades = await api.get('/actividades?centro_id=$centroId') as List;
      final tipos = await api.get('/tipos-actividad') as List;
      setState(() {
        for (final c in centros) {
          if (c['id'] == centroId) _centro = Centro.desdeJson(c as Map<String, dynamic>);
        }
        _cargado = true;
        _contrato = contrato
            .map((l) => LineaContrato.desdeJson(l as Map<String, dynamic>))
            .where((l) => l.activa)
            .toList();
        // Las más recientes primero
        _actividades = actividades.map((a) => Actividad.desdeJson(a as Map<String, dynamic>)).toList().reversed.toList();
        _tipos = tipos.map((t) => TipoActividad.desdeJson(t as Map<String, dynamic>)).toList();
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  void _avisar(String mensaje, {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), action: accion));
  }

  /// Cambiar el nombre, el nº de cliente, el CIF o la dirección del centro.
  Future<void> _editar() async {
    final datos = await pedirDatosCentro(context, centro: _centro);
    if (datos == null) return;
    try {
      await api.patch('/clientes/${widget.cliente.id}/centros/${_centro.id}', datos);
      await _cargar();
      _avisar('Datos del centro guardados');
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  /// Muestra la lista de tipos de actividad para elegir uno.
  Future<TipoActividad?> _elegirTipo(String titulo, {Set<int> excluir = const {}}) {
    final disponibles = _tipos.where((t) => !excluir.contains(t.id)).toList();
    return showModalBottomSheet<TipoActividad>(
      context: context,
      backgroundColor: Paleta.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (contexto) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (disponibles.isEmpty)
              Text('Ya están todas añadidas.', style: TextStyle(color: Paleta.tintaSuave)),
            for (final tipo in disponibles)
              Card(
                child: ListTile(
                  leading: Icon(Icons.assignment_outlined, color: Paleta.naranja),
                  title: Text(tipo.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(contexto).pop(tipo),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _anadirAlContrato() async {
    final tipo = await _elegirTipo(
      'Añadir al contrato',
      excluir: _contrato.map((l) => l.tipoActividadId).toSet(),
    );
    if (tipo == null) return;
    try {
      await api.post('/clientes/${widget.cliente.id}/obligatorias', {
        'tipo_actividad_id': tipo.id,
        'centro_id': _centro.id,
      });
      await _cargar();
      _avisar('"${tipo.nombre}" añadida al contrato');
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _quitarDelContrato(LineaContrato linea) async {
    try {
      await api.borrar('/clientes/${widget.cliente.id}/obligatorias/${linea.id}');
      await _cargar();
      if (!mounted) return;
      // En lugar de preguntar "¿estás seguro?", se ofrece deshacer
      _avisar(
        '"${linea.tipoNombre}" quitada del contrato',
        accion: SnackBarAction(
          label: 'DESHACER',
          textColor: Paleta.morado,
          onPressed: () async {
            await api.post('/clientes/${widget.cliente.id}/obligatorias', {
              'tipo_actividad_id': linea.tipoActividadId,
              'centro_id': _centro.id,
              'desde_anio': linea.desdeAnio,
            });
            _cargar();
          },
        ),
      );
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _anadirExtra() async {
    final tipo = await _elegirTipo('Nueva actividad extra');
    if (tipo == null) return;
    try {
      final creada = await api.post('/actividades', {
        'cliente_id': widget.cliente.id,
        'centro_id': _centro.id,
        'tipo_actividad_id': tipo.id,
      }) as Map<String, dynamic>;
      await _cargar();
      if (!mounted) return;
      await _abrir(creada['id'] as int);
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _abrir(int actividadId) async {
    final cambiada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ActividadPantalla(actividadId: actividadId)),
    );
    if (cambiada == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.cliente;
    final codigo = _centro.codigo;
    final primerAnio = DateTime.now().year - 4; // margen de 5 años
    final faltan = _actividades.where((a) => !a.realizada && a.anio >= primerAnio).toList()
      ..sort((a, b) => a.anio.compareTo(b.anio)); // lo más antiguo (lo más urgente) primero
    final hechas = _actividades.where((a) => a.realizada).toList()
      ..sort((a, b) => b.anio.compareTo(a.anio)); // lo más reciente primero
    final lista = _verHechas ? hechas : faltan;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Cabecera(
          // Arriba, la sociedad y el nº de cliente del centro: "Hotel Brisa · Nº 11569"
          sobretitulo: codigo == null || codigo.isEmpty ? cliente.nombre : '${cliente.nombre} · Nº $codigo',
          titulo: _centro.nombre,
        ),
        actions: [
          IconButton(tooltip: 'Editar centro', onPressed: _editar, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
              : !_cargado
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          // Las dos partes de la carpeta
                          Row(
                            children: [
                              Expanded(
                                child: _BotonParte(
                                  texto: 'Le faltan',
                                  cantidad: faltan.length,
                                  elegido: !_verHechas,
                                  alPulsar: () => setState(() => _verHechas = false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _BotonParte(
                                  texto: 'Hechas',
                                  cantidad: hechas.length,
                                  elegido: _verHechas,
                                  alPulsar: () => setState(() => _verHechas = true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (lista.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                _verHechas
                                    ? 'Todavía no hay actividades hechas.'
                                    : (_contrato.isEmpty
                                        ? 'No le falta nada.\nSi este centro tiene actividades cada año, añádelas en "Contrato", más abajo.'
                                        : 'No le falta nada. ¡Todo al día!'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Paleta.tintaSuave, fontSize: 16),
                              ),
                            ),
                          // Agrupadas por año, con el año como separador
                          for (final (indice, actividad) in lista.indexed) ...[
                            if (indice == 0 || lista[indice - 1].anio != actividad.anio)
                              _CabeceraAnio(anio: actividad.anio, atrasado: !_verHechas && actividad.atrasada),
                            _TarjetaActividadCliente(
                              actividad: actividad,
                              estado: _estado(actividad),
                              alPulsar: () => _abrir(actividad.id),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _anadirExtra,
                              icon: const Icon(Icons.add),
                              label: const Text('Actividad extra'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Plegable(
                            icono: Icons.store_outlined,
                            titulo: 'Datos del centro',
                            children: [_DatosCentro(centro: _centro)],
                          ),
                          const SizedBox(height: 10),
                          _Plegable(
                            icono: Icons.autorenew,
                            titulo: 'Contrato · ${_contrato.length} ${_contrato.length == 1 ? 'actividad' : 'actividades'} al año',
                            children: [
                              if (_contrato.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Text(
                                    'Añade las actividades que este centro necesita cada año.',
                                    style: TextStyle(color: Paleta.tintaSuave),
                                  ),
                                ),
                              for (final linea in _contrato)
                                ListTile(
                                  title: Text(linea.tipoNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('Cada año desde ${linea.desdeAnio}'),
                                  trailing: IconButton(
                                    tooltip: 'Quitar del contrato',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _quitarDelContrato(linea),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                  child: TextButton.icon(
                                    onPressed: _anadirAlContrato,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Añadir al contrato'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  String _estado(Actividad a) {
    final tipo = a.obligatoria ? '' : 'Extra · ';
    if (a.realizada) {
      final cuando = a.fechaRealizacion == null ? 'Realizada' : 'Realizada el ${fechaTexto(a.fechaRealizacion!)}';
      final codigo = a.codigoPresupuesto == null ? '' : ' · ${a.codigoPresupuesto}';
      return '$tipo$cuando$codigo';
    }
    if (a.fechaProgramada != null) return '${tipo}Visita el ${fechaTexto(a.fechaProgramada!)}';
    return '$tipo${a.atrasada ? 'Atrasada · sin programar' : 'Sin programar'}';
  }
}

/// Uno de los dos botones de arriba de la carpeta: "Le faltan · 3" o "Hechas · 5".
class _BotonParte extends StatelessWidget {
  final String texto;
  final int cantidad;
  final bool elegido;
  final VoidCallback alPulsar;

  const _BotonParte({required this.texto, required this.cantidad, required this.elegido, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegido ? Paleta.lavanda : Paleta.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: elegido ? Paleta.morado : Paleta.borde, width: elegido ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Column(
            children: [
              Text('$cantidad', style: TextStyle(fontSize: 26, color: Paleta.tinta, height: 1.1)),
              Text(
                texto,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: elegido ? Paleta.tinta : Paleta.tintaSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separador con el año ("2024 · de años anteriores" en rojo si quedan cosas atrasadas).
class _CabeceraAnio extends StatelessWidget {
  final int anio;
  final bool atrasado;

  const _CabeceraAnio({required this.anio, required this.atrasado});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          Text(
            '$anio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: atrasado ? Paleta.rojo : Paleta.tinta),
          ),
          if (atrasado) ...[
            const SizedBox(width: 8),
            Text('de años anteriores', style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(width: 10),
          Expanded(child: Divider(color: atrasado ? Paleta.rojoBorde : Paleta.borde)),
        ],
      ),
    );
  }
}

/// Apartado que se abre y se cierra (dirección y contrato): cerrado por defecto,
/// para que la carpeta muestre primero lo importante.
class _Plegable extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Widget> children;

  const _Plegable({required this.icono, required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icono, color: Paleta.morado),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          childrenPadding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }
}

/// Datos del centro: nº de cliente, CIF y dirección (con el botón para abrirla en Google Maps).
class _DatosCentro extends StatelessWidget {
  final Centro centro;

  const _DatosCentro({required this.centro});

  @override
  Widget build(BuildContext context) {
    final filas = <(IconData, String, String)>[
      if (centro.codigo != null && centro.codigo!.isNotEmpty) (Icons.tag, 'Nº de cliente', centro.codigo!),
      if (centro.cif != null && centro.cif!.isNotEmpty) (Icons.badge_outlined, 'CIF / NIF', centro.cif!),
      if (centro.direccion != null && centro.direccion!.isNotEmpty) (Icons.place_outlined, 'Dirección', centro.direccion!),
    ];
    if (filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Sin nº de cliente, CIF ni dirección. Pulsa ✏️ arriba para añadirlos.',
          style: TextStyle(color: Paleta.tintaSuave),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (final (icono, etiqueta, texto) in filas)
            ListTile(
              dense: true,
              leading: Icon(icono, color: Paleta.tinta),
              title: Text(etiqueta, style: TextStyle(color: Paleta.tintaSuave, fontSize: 12)),
              subtitle: SelectableText(texto, style: TextStyle(fontSize: 16, color: Paleta.tinta)),
              trailing: icono == Icons.place_outlined
                  ? IconButton(
                      tooltip: 'Abrir en Google Maps',
                      onPressed: () => abrirEnMapas(texto),
                      icon: Icon(Icons.directions_outlined, color: Paleta.morado),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Actividad en la carpeta del centro: roja si está atrasada, lavanda si está hecha.
class _TarjetaActividadCliente extends StatelessWidget {
  final Actividad actividad;
  final String estado;
  final VoidCallback alPulsar;

  const _TarjetaActividadCliente({required this.actividad, required this.estado, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final atrasada = actividad.atrasada;
    final hecha = actividad.realizada;
    final fondo = atrasada ? Paleta.rojoSuave : (hecha ? Paleta.lavandaSuave : Paleta.blanco);
    final borde = atrasada ? Paleta.rojoBorde : (hecha ? Colors.transparent : Paleta.borde);
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
                Icon(
                  hecha ? Icons.check_circle_outline : (atrasada ? Icons.warning_amber_rounded : Icons.event_note_outlined),
                  color: hecha ? Paleta.morado : (atrasada ? Paleta.rojo : Paleta.tinta),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(actividad.tipoNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        estado,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hecha || atrasada ? FontWeight.w700 : FontWeight.normal,
                          color: hecha ? Paleta.morado : (atrasada ? Paleta.rojo : Paleta.tintaSuave),
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
