import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';
import '../utilidades/turnos.dart';
import '../widgets/selector_turno.dart';
import 'incentivos.dart';

/// "Registro": todo lo que el técnico entrega, en tres pestañas: Incentivos, Km y Formación.
class RegistroPantalla extends StatelessWidget {
  const RegistroPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Paleta.blanco,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Paleta.borde),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Paleta.lavanda,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Paleta.morado),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Paleta.tinta,
                unselectedLabelColor: Paleta.tintaSuave,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(height: 40, text: 'Incentivos'),
                  Tab(height: 40, text: 'Km'),
                  Tab(height: 40, text: 'Formación'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                IncentivosPantalla(),
                _ListaRegistros(tipo: 'kilometros'),
                _ListaRegistros(tipo: 'formacion'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un registro: km recorridos o horas de formación de un día.
class _Registro {
  final int id;
  final DateTime fecha;
  final String tipo; // kilometros o formacion
  final double cantidad;
  final String? concepto;
  final String? turno; // solo formación: manana, tarde, extra_manana, extra_tarde
  final int? actividadId; // si se apuntó al hacer el check

  _Registro.desdeJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        fecha = DateTime.parse(json['fecha'] as String),
        tipo = json['tipo'] as String,
        cantidad = (json['cantidad'] as num).toDouble(),
        concepto = json['concepto'] as String?,
        turno = json['turno'] as String?,
        actividadId = json['actividad_id'] as int?;
}

/// Lista de un mes de km o de formación, con el total y el botón para apuntar.
class _ListaRegistros extends StatefulWidget {
  final String tipo;

  const _ListaRegistros({required this.tipo});

  @override
  State<_ListaRegistros> createState() => _ListaRegistrosState();
}

class _ListaRegistrosState extends State<_ListaRegistros> with AutomaticKeepAliveClientMixin {
  late DateTime _mes;
  List<_Registro> _registros = [];
  Map<String, double> _horasPorTurno = {};
  bool _cargando = true;
  String? _error;

  bool get _esKm => widget.tipo == 'kilometros';
  String get _unidad => _esKm ? 'km' : 'h';
  double get _total => _registros.fold(0.0, (suma, r) => suma + r.cantidad);

  // Mantiene la pestaña viva al cambiar entre Incentivos, Km y Formación
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await api.get('/registros?anio=${_mes.year}&mes=${_mes.month}') as Map<String, dynamic>;
      setState(() {
        _registros = (datos['registros'] as List)
            .map((r) => _Registro.desdeJson(r as Map<String, dynamic>))
            .where((r) => r.tipo == widget.tipo)
            .toList();
        _horasPorTurno = (datos['horas_por_turno'] as Map<String, dynamic>)
            .map((turno, horas) => MapEntry(turno, (horas as num).toDouble()));
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarMes(int desplazamiento) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + desplazamiento));
    _cargar();
  }

  void _avisar(String mensaje, {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), action: accion));
  }

  Future<void> _anadir() async {
    final nuevo = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Paleta.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormularioRegistro(tipo: widget.tipo),
    );
    if (nuevo == null) return;
    try {
      await api.post('/registros', nuevo);
      final fecha = DateTime.parse(nuevo['fecha'] as String);
      _mes = DateTime(fecha.year, fecha.month);
      await _cargar();
      _avisar('Guardado');
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _borrar(_Registro registro) async {
    try {
      await api.borrar('/registros/${registro.id}');
      await _cargar();
      if (!mounted) return;
      _avisar(
        'Registro borrado',
        accion: SnackBarAction(
          label: 'DESHACER',
          textColor: Paleta.morado,
          onPressed: () async {
            await api.post('/registros', {
              'fecha': fechaApi(registro.fecha),
              'tipo': registro.tipo,
              'cantidad': registro.cantidad,
              'concepto': registro.concepto,
              'turno': registro.turno,
            });
            _cargar();
          },
        ),
      );
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    }
  }

  /// Copia un resumen del mes para pegarlo en un correo o en un documento.
  Future<void> _copiarResumen() async {
    final nombre = api.usuario?.nombre ?? '';
    final queEs = _esKm ? 'Kilómetros' : 'Horas de formación';
    final lineas = [
      '$queEs · $nombre · ${meses[_mes.month - 1]} ${_mes.year}',
      '',
      for (final r in _registros)
        '${fechaTexto(r.fecha)}  ${numero(r.cantidad)} $_unidad'
            '${r.turno == null ? '' : '  (${nombresTurno[r.turno]})'}'
            '${r.concepto == null ? '' : '  ·  ${r.concepto}'}',
      '',
      if (!_esKm)
        for (final turno in turnos) '${nombresTurno[turno]}: ${numero(_horasPorTurno[turno] ?? 0)} h',
      'TOTAL: ${numero(_total)} $_unidad',
    ];
    await Clipboard.setData(ClipboardData(text: lineas.join('\n')));
    _avisar('Resumen copiado. Ya puedes pegarlo en un correo.');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final icono = _esKm ? Icons.directions_car : Icons.school;
    // Agrupar por día, los más recientes primero
    final porDia = <DateTime, List<_Registro>>{};
    for (final r in _registros.reversed) {
      porDia.putIfAbsent(r.fecha, () => []).add(r);
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => _cambiarMes(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Mes anterior'),
                  Expanded(
                    child: Text(
                      '${meses[_mes.month - 1]} ${_mes.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(onPressed: () => _cambiarMes(1), icon: const Icon(Icons.chevron_right), tooltip: 'Mes siguiente'),
                ],
              ),
              if (_cargando) const LinearProgressIndicator() else const SizedBox(height: 4),
              const SizedBox(height: 8),
              TarjetaResumen(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${meses[_mes.month - 1]} ${_mes.year}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(icono, color: Paleta.tinta),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${numero(_total)} $_unidad', style: estiloCifra),
                    const SizedBox(height: 4),
                    Text(
                      _esKm
                          ? '${_registros.length} ${_registros.length == 1 ? 'trayecto guardado' : 'trayectos guardados'}'
                          : 'de formación este mes',
                      style: TextStyle(color: Paleta.tintaSuave),
                    ),
                  ],
                ),
              ),
              if (!_esKm) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final turno in turnos)
                      Expanded(child: _HorasTurno(turno: turno, horas: _horasPorTurno[turno] ?? 0)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (_registros.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _copiarResumen,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar resumen del mes'),
                  ),
                ),
              if (_error != null) Text(_error!),
              if (!_cargando && _registros.isEmpty && _error == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _esKm
                        ? 'Sin km este mes.\nSe apuntan solos al hacer el check de una visita, o pulsa "Apuntar".'
                        : 'Sin formación este mes.\nSe apunta sola al hacer el check de una visita, o pulsa "Apuntar".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Paleta.tintaSuave, fontSize: 15),
                  ),
                ),
              for (final dia in porDia.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                  child: Text(
                    fechaLarga(dia.key),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tintaSuave),
                  ),
                ),
                for (final registro in dia.value)
                  Dismissible(
                    key: ValueKey(registro.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      // Se quita de la lista al momento (Flutter lo exige) y luego se borra en la API
                      setState(() => _registros.removeWhere((r) => r.id == registro.id));
                      _borrar(registro);
                    },
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.only(right: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Paleta.lavandaSuave,
                          foregroundColor: Paleta.morado,
                          child: Icon(icono, size: 20),
                        ),
                        title: Text(
                          '${numero(registro.cantidad)} $_unidad',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (registro.turno != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 2),
                                child: _EtiquetaTurno(turno: registro.turno!),
                              ),
                            if (registro.concepto != null) Text(registro.concepto!),
                            if (registro.actividadId != null)
                              Row(
                                children: [
                                  Icon(Icons.verified, size: 14, color: Paleta.sello),
                                  SizedBox(width: 4),
                                  Text('Apuntado con el check', style: TextStyle(fontSize: 12, color: Paleta.sello)),
                                ],
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _borrar(registro),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'apuntar-${widget.tipo}',
            onPressed: _anadir,
            icon: const Icon(Icons.add),
            label: Text(_esKm ? 'Apuntar km' : 'Apuntar formación', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Formulario para apuntar km o formación a mano.
class _FormularioRegistro extends StatefulWidget {
  final String tipo;

  const _FormularioRegistro({required this.tipo});

  @override
  State<_FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends State<_FormularioRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _cantidad = TextEditingController();
  final _concepto = TextEditingController();
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  late String _turno = turnoPara(_fecha);

  bool get _esKm => widget.tipo == 'kilometros';

  @override
  void dispose() {
    _cantidad.dispose();
    _concepto.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      helpText: '¿Qué día?',
    );
    if (elegida == null) return;
    setState(() {
      _fecha = elegida;
      // Al cambiar el día se vuelve a proponer el turno (extra en fin de semana)
      _turno = turnoPara(elegida, tarde: esDeTarde(_turno));
    });
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;
    final concepto = _concepto.text.trim();
    Navigator.of(context).pop(<String, dynamic>{
      'fecha': fechaApi(_fecha),
      'tipo': widget.tipo,
      'cantidad': leerImporte(_cantidad.text),
      'concepto': concepto.isEmpty ? null : concepto,
      'turno': _esKm ? null : _turno,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Paleta.papelOscuro, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_esKm ? 'Apuntar km' : 'Apuntar formación', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Día', prefixIcon: Icon(Icons.event)),
                  child: Text(fechaTexto(_fecha), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cantidad,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _esKm ? 'Kilómetros' : 'Horas de formación',
                  suffixText: _esKm ? 'km' : 'h',
                  prefixIcon: Icon(_esKm ? Icons.speed : Icons.timer_outlined),
                ),
                validator: (v) {
                  final n = leerImporte(v ?? '');
                  if (n == null || n <= 0) return 'Escribe una cantidad';
                  if (n > 2000) return 'La cantidad parece demasiado grande';
                  return null;
                },
              ),
              if (!_esKm) ...[
                const SizedBox(height: 14),
                SelectorTurno(valor: _turno, fecha: _fecha, alCambiar: (t) => setState(() => _turno = t)),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _concepto,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Concepto (opcional)',
                  hintText: _esKm ? 'Ej.: Palma → Inca (Talleres Ramírez)' : 'Ej.: Curso de primeros auxilios',
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _guardar, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horas de un turno, en una cajita pequeña.
class _HorasTurno extends StatelessWidget {
  final String turno;
  final double horas;

  const _HorasTurno({required this.turno, required this.horas});

  @override
  Widget build(BuildContext context) {
    final extra = turno.startsWith('extra');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Paleta.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: extra ? Paleta.morado : Paleta.borde, width: extra ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Text('${numero(horas)} h', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(
            nombresTurno[turno]!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: extra ? Paleta.morado : Paleta.tintaSuave, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaTurno extends StatelessWidget {
  final String turno;

  const _EtiquetaTurno({required this.turno});

  @override
  Widget build(BuildContext context) {
    final extra = turno.startsWith('extra');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: extra ? Paleta.lavanda : Paleta.fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        nombresTurno[turno] ?? turno,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: extra ? Paleta.morado : Paleta.tinta),
      ),
    );
  }
}
