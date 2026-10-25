import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../modelos/cliente.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';
import '../utilidades/mapas.dart';
import '../widgets/sello.dart';
import '../widgets/selector_tecnico.dart';

/// Ficha de una actividad: programar la visita y hacer el check de "realizada".
///
/// Al volver atrás devuelve `true` si ha cambiado algo, para que la lista se recargue.
class ActividadPantalla extends StatefulWidget {
  final int actividadId;

  const ActividadPantalla({super.key, required this.actividadId});

  @override
  State<ActividadPantalla> createState() => _ActividadPantallaState();
}

class _ActividadPantallaState extends State<ActividadPantalla> {
  Actividad? _actividad;
  List<Tecnico> _tecnicos = [];
  List<Centro> _centros = []; // centros de la sociedad, para elegir dónde se hace la visita
  String? _error;
  bool _ocupado = false;
  bool _cambiada = false;
  bool _recienSellada = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await api.get('/actividades/${widget.actividadId}') as Map<String, dynamic>;
      final tecnicos = await api.tecnicos();
      final actividad = Actividad.desdeJson(datos);
      // Los centros de la sociedad. Si no se pueden ver (p. ej. la sociedad es de otro técnico),
      // simplemente no se ofrece cambiar el centro.
      var centros = <Centro>[];
      try {
        final lista = await api.get('/clientes/${actividad.clienteId}/centros') as List;
        centros = lista.map((c) => Centro.desdeJson(c as Map<String, dynamic>)).toList();
      } on ApiError {
        centros = [];
      }
      setState(() {
        _actividad = actividad;
        _tecnicos = tecnicos;
        _centros = centros;
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Ejecuta una acción contra la API mostrando que está trabajando y avisando si falla.
  Future<void> _hacer(Future<Map<String, dynamic>> Function() accion, {String? exito}) async {
    setState(() => _ocupado = true);
    try {
      final datos = await accion();
      setState(() {
        _actividad = Actividad.desdeJson(datos);
        _cambiada = true;
      });
      if (exito != null) _avisar(exito);
    } on ApiError catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _programar() async {
    final cambios = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Paleta.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormularioVisita(actividad: _actividad!),
    );
    if (cambios == null) return;
    await _hacer(
      () async => await api.patch('/actividades/${widget.actividadId}', cambios) as Map<String, dynamic>,
      exito: 'Visita guardada',
    );
  }

  Future<void> _quitarFecha() async {
    await _hacer(
      () async =>
          await api.patch('/actividades/${widget.actividadId}', {'fecha_programada': null}) as Map<String, dynamic>,
      exito: 'Se ha quitado la visita',
    );
  }

  Future<void> _cambiarParticipante(String campo, int? tecnicoId) async {
    await _hacer(
      () async => await api.patch('/actividades/${widget.actividadId}', {campo: tecnicoId}) as Map<String, dynamic>,
      exito: campo == 'captador_id' ? 'Captador actualizado' : 'Redactor actualizado',
    );
  }

  Future<void> _cambiarCentro(int? centroId) async {
    if (centroId == null || centroId == _actividad?.centroId) return;
    await _hacer(
      () async =>
          await api.patch('/actividades/${widget.actividadId}', {'centro_id': centroId}) as Map<String, dynamic>,
      exito: 'Centro de trabajo actualizado',
    );
  }

  Future<void> _hacerCheck() async {
    final hecha = await showModalBottomSheet<Actividad>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Paleta.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormularioCheck(actividad: _actividad!, tecnicos: _tecnicos),
    );
    if (hecha == null) return;
    setState(() {
      _actividad = hecha;
      _cambiada = true;
      _recienSellada = true;
    });
    _avisar('¡Hecho! Se ha avisado a presupuestos.');
  }

  Future<void> _deshacer() async {
    setState(() => _recienSellada = false);
    await _hacer(
      () async => await api.post('/actividades/${widget.actividadId}/deshacer') as Map<String, dynamic>,
      exito: 'Se ha quitado el check',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) {
        if (!yaSalio) Navigator.of(context).pop(_cambiada);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 84,
          title: Cabecera(sobretitulo: _actividad?.clienteYCentro ?? 'Actividad', titulo: 'Detalle de actividad'),
        ),
        body: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: _cuerpo()),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final actividad = _actividad;
    if (actividad == null) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Cabecera(actividad: actividad),
            const SizedBox(height: 16),
            if (actividad.realizada)
              _Realizada(actividad: actividad, animar: _recienSellada, alDeshacer: _ocupado ? null : _deshacer)
            else ...[
              _Visita(
                actividad: actividad,
                alProgramar: _ocupado ? null : _programar,
                alQuitar: _ocupado ? null : _quitarFecha,
              ),
              const SizedBox(height: 12),
              _Bloque(
                titulo: 'Quién participa',
                child: Column(
                  children: [
                    SelectorTecnico(
                      etiqueta: 'Captador (consiguió la actividad)',
                      icono: Icons.handshake_outlined,
                      valor: actividad.captadorId,
                      nombreValor: actividad.captadorNombre,
                      textoPorDefecto: 'El técnico del cliente',
                      tecnicos: _tecnicos,
                      alCambiar: _ocupado ? null : (id) => _cambiarParticipante('captador_id', id),
                    ),
                    const SizedBox(height: 12),
                    SelectorTecnico(
                      etiqueta: 'Redactor (la realiza)',
                      icono: Icons.edit_note,
                      valor: actividad.redactorId,
                      nombreValor: actividad.redactorNombre,
                      textoPorDefecto: 'Quien haga el check',
                      tecnicos: _tecnicos,
                      alCambiar: _ocupado ? null : (id) => _cambiarParticipante('redactor_id', id),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Bloque(
                titulo: 'Centro de trabajo',
                child: _centros.length > 1
                    ? DropdownButtonFormField<int>(
                        // La key hace que se redibuje con el valor nuevo al cambiarlo
                        key: ValueKey(actividad.centroId),
                        initialValue: _centros.any((c) => c.id == actividad.centroId) ? actividad.centroId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.store_outlined)),
                        items: [
                          for (final centro in _centros)
                            DropdownMenuItem(
                              value: centro.id,
                              child: Text(
                                centro.codigo == null || centro.codigo!.isEmpty
                                    ? centro.nombre
                                    : '${centro.nombre} · Nº ${centro.codigo}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _ocupado ? null : _cambiarCentro,
                      )
                    : Row(
                        children: [
                          Icon(Icons.store_outlined, color: Paleta.tinta),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              [
                                actividad.centroNombre ?? 'Sin centro',
                                if (actividad.centroCodigo != null && actividad.centroCodigo!.isNotEmpty)
                                  'Nº ${actividad.centroCodigo}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _ocupado ? null : _hacerCheck,
                icon: const Icon(Icons.task_alt, size: 26),
                label: const Text('Marcar como realizada'),
              ),
              const SizedBox(height: 8),
              Text(
                'Se avisará automáticamente a presupuestos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Paleta.tintaSuave),
              ),
            ],
            if (actividad.notas != null && actividad.notas!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Bloque(titulo: 'Notas', child: Text(actividad.notas!)),
            ],
          ],
        ),
        if (_ocupado) const LinearProgressIndicator(),
      ],
    );
  }
}

/// Aviso de atrasada (si lo está), tipo de actividad en grande y cliente.
class _Cabecera extends StatelessWidget {
  final Actividad actividad;

  const _Cabecera({required this.actividad});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actividad.atrasada) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Paleta.rojoSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Paleta.rojoBorde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Paleta.rojo, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'ATRASADA · ${actividad.anio}',
                      style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Es del contrato de ${actividad.anio} y todavía no se ha hecho.',
                  style: TextStyle(color: Paleta.rojo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          actividad.tipoNombre,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.3),
        ),
        const SizedBox(height: 6),
        Text(
          '${actividad.clienteYCentro} · ${actividad.obligatoria ? 'Contrato' : 'Actividad extra'} ${actividad.anio}',
          style: TextStyle(fontSize: 16, color: Paleta.tintaSuave),
        ),
      ],
    );
  }
}

/// Recuadro blanco con un título.
class _Bloque extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _Bloque({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// La visita: día, hora y lugar, con botones para programarla, cambiarla o quitarla.
class _Visita extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback? alProgramar;
  final VoidCallback? alQuitar;

  const _Visita({required this.actividad, required this.alProgramar, required this.alQuitar});

  @override
  Widget build(BuildContext context) {
    final fecha = actividad.fechaProgramada;
    final destino = actividad.destino;
    return _Bloque(
      titulo: 'Visita',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fecha == null)
            Row(
              children: [
                Icon(Icons.event_busy, color: Paleta.tintaSuave),
                SizedBox(width: 10),
                Text('Sin fecha todavía', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            )
          else
            Row(
              children: [
                _HojaCalendario(fecha: fecha),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fechaLarga(fecha), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: Paleta.naranja),
                          const SizedBox(width: 4),
                          Text(
                            actividad.horaProgramada ?? 'Sin hora',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Quitar visita', onPressed: alQuitar, icon: const Icon(Icons.close)),
              ],
            ),
          if (destino != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Paleta.papel, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.place, color: Paleta.naranja),
                  const SizedBox(width: 8),
                  Expanded(child: SelectableText(destino, style: const TextStyle(fontSize: 15))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => abrirEnMapas(destino),
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text('Cómo llegar'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: alProgramar,
            icon: const Icon(Icons.edit_calendar),
            label: Text(fecha == null ? 'Programar visita' : 'Cambiar visita'),
          ),
        ],
      ),
    );
  }
}

/// Hoja de calendario pequeña: mes arriba en naranja y el día grande.
class _HojaCalendario extends StatelessWidget {
  final DateTime fecha;

  const _HojaCalendario({required this.fecha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Paleta.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paleta.papelOscuro, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Paleta.naranja,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              mesesCortos[fecha.month - 1].toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Paleta.blanco, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${fecha.day}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

/// Actividad ya realizada: el sello, los datos del check y los incentivos.
class _Realizada extends StatelessWidget {
  final Actividad actividad;
  final bool animar;
  final VoidCallback? alDeshacer;

  const _Realizada({required this.actividad, required this.animar, required this.alDeshacer});

  @override
  Widget build(BuildContext context) {
    final fecha = actividad.fechaRealizacion == null ? null : fechaTexto(actividad.fechaRealizacion!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: animar ? SelloAnimado(fecha: fecha) : Sello(fecha: fecha)),
        ),
        _Bloque(
          titulo: 'Datos del check',
          child: Column(
            children: [
              _Dato(etiqueta: 'Presupuesto', valor: actividad.codigoPresupuesto ?? '—'),
              _Dato(
                etiqueta: 'Importe sin IVA',
                valor: actividad.importePresupuesto == null ? '—' : euros(actividad.importePresupuesto!),
              ),
              _Dato(etiqueta: 'Fecha', valor: fecha ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Bloque(
          titulo: 'Incentivos',
          child: Column(
            children: [
              _Dato(
                etiqueta: 'Captador · ${actividad.captadorNombre ?? '—'}',
                valor: actividad.importeCaptador == null ? '—' : euros(actividad.importeCaptador!),
              ),
              _Dato(
                etiqueta: 'Redactor · ${actividad.redactorNombre ?? '—'}',
                valor: actividad.importeRedactor == null ? '—' : euros(actividad.importeRedactor!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: alDeshacer,
          icon: const Icon(Icons.undo),
          label: const Text('¿Te has equivocado? Quitar el check'),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: TextStyle(color: Paleta.tintaSuave))),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

/// Formulario del check: código de presupuesto, fecha e importe sin IVA.
class _FormularioCheck extends StatefulWidget {
  final Actividad actividad;
  final List<Tecnico> tecnicos;

  const _FormularioCheck({required this.actividad, required this.tecnicos});

  @override
  State<_FormularioCheck> createState() => _FormularioCheckState();
}

class _FormularioCheckState extends State<_FormularioCheck> {
  final _formulario = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _importe = TextEditingController();
  late DateTime _fecha;
  int? _captador;
  int? _redactor;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Por defecto, la fecha programada si ya pasó; si no, hoy
    final hoy = DateUtils.dateOnly(DateTime.now());
    final programada = widget.actividad.fechaProgramada;
    _fecha = (programada != null && !programada.isAfter(hoy)) ? programada : hoy;
    _captador = widget.actividad.captadorId;
    // Si no hay redactor, por defecto quien hace el check (si es técnico)
    final yo = api.usuario;
    _redactor = widget.actividad.redactorId ?? (yo != null && yo.rol == 'tecnico' ? yo.id : null);
  }

  @override
  void dispose() {
    _codigo.dispose();
    _importe.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      helpText: '¿Qué día se realizó?',
    );
    if (elegida == null) return;
    setState(() => _fecha = elegida);
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final datos = await api.post('/actividades/${widget.actividad.id}/realizar', {
        'codigo_presupuesto': _codigo.text.trim(),
        'fecha_realizacion': fechaApi(_fecha),
        'importe_presupuesto': leerImporte(_importe.text),
        'captador_id': _captador,
        'redactor_id': _redactor,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pop(Actividad.desdeJson(datos));
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El padding de abajo sube el formulario cuando aparece el teclado;
    // el scroll permite verlo entero en móviles pequeños
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
            const Text('Marcar como realizada', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(widget.actividad.clienteYCentro, style: TextStyle(color: Paleta.tintaSuave)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _codigo,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Código de presupuesto',
                hintText: 'P-2026-0458',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el código del presupuesto' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _importe,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Importe sin IVA',
                hintText: '1250,00',
                prefixIcon: Icon(Icons.euro),
              ),
              validator: (v) {
                final importe = leerImporte(v ?? '');
                if (importe == null || importe <= 0) return 'Escribe el importe del presupuesto sin IVA';
                return null;
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _elegirFecha,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha de realización', prefixIcon: Icon(Icons.event)),
                child: Row(
                  children: [
                    Text(fechaTexto(_fecha), style: const TextStyle(fontSize: 16)),
                    const Spacer(),
                    Text('Cambiar', style: TextStyle(color: Paleta.naranja, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SelectorTecnico(
              etiqueta: 'Captador',
              icono: Icons.handshake_outlined,
              valor: _captador,
              nombreValor: widget.actividad.captadorNombre,
              textoPorDefecto: 'El técnico del cliente',
              tecnicos: widget.tecnicos,
              alCambiar: (id) => setState(() => _captador = id),
            ),
            const SizedBox(height: 14),
            SelectorTecnico(
              etiqueta: 'Redactor',
              icono: Icons.edit_note,
              valor: _redactor,
              nombreValor: widget.actividad.redactorNombre,
              textoPorDefecto: 'Quien haga el check',
              tecnicos: widget.tecnicos,
              alCambiar: (id) => setState(() => _redactor = id),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Paleta.morado))
                  : const Text('Sellar como realizada'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Formulario de la visita: día, hora (opcional) y dirección o zona.
/// Devuelve los cambios para enviar a la API.
class _FormularioVisita extends StatefulWidget {
  final Actividad actividad;

  const _FormularioVisita({required this.actividad});

  @override
  State<_FormularioVisita> createState() => _FormularioVisitaState();
}

class _FormularioVisitaState extends State<_FormularioVisita> {
  late DateTime _fecha;
  TimeOfDay? _hora;
  late final _lugar = TextEditingController(text: widget.actividad.destino);

  @override
  void initState() {
    super.initState();
    _fecha = widget.actividad.fechaProgramada ?? DateUtils.dateOnly(DateTime.now());
    final hora = widget.actividad.horaProgramada;
    if (hora != null) {
      final partes = hora.split(':');
      _hora = TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
    }
  }

  @override
  void dispose() {
    _lugar.dispose();
    super.dispose();
  }

  String? get _horaTexto {
    final hora = _hora;
    if (hora == null) return null;
    return '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
      helpText: '¿Qué día es la visita?',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: '¿A qué hora?',
      builder: (context, hijo) => MediaQuery(
        // Formato de 24 horas, como se usa en España
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: hijo!,
      ),
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  void _guardar() {
    final lugar = _lugar.text.trim();
    Navigator.of(context).pop(<String, dynamic>{
      'fecha_programada': fechaApi(_fecha),
      'hora_programada': _horaTexto,
      'lugar': lugar.isEmpty ? null : lugar,
    });
  }

  Widget _selector({required IconData icono, required String etiqueta, required String valor, required VoidCallback alPulsar}) {
    return InkWell(
      onTap: alPulsar,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: Icon(icono)),
        child: Text(valor, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
            const Text('Programar visita', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(widget.actividad.clienteYCentro, style: TextStyle(color: Paleta.tintaSuave)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _selector(icono: Icons.event, etiqueta: 'Día', valor: fechaTexto(_fecha), alPulsar: _elegirFecha),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _selector(
                    icono: Icons.schedule,
                    etiqueta: 'Hora',
                    valor: _horaTexto ?? '—',
                    alPulsar: _elegirHora,
                  ),
                ),
              ],
            ),
            if (_hora != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _hora = null), child: const Text('Quitar hora')),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _lugar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dirección o zona',
                hintText: 'Ej.: Polígono de Inca, nave 7',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _guardar, child: const Text('Guardar visita')),
          ],
        ),
      ),
    );
  }
}
