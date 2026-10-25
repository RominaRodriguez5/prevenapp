import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';
import '../utilidades/mapas.dart';
import 'actividad.dart';

/// Mi calendario: franja con los días de la semana (o el mes completo), guardia del día
/// y visitas en línea de tiempo.
class CalendarioPantalla extends StatefulWidget {
  const CalendarioPantalla({super.key});

  @override
  State<CalendarioPantalla> createState() => _CalendarioPantallaState();
}

class _CalendarioPantallaState extends State<CalendarioPantalla> {
  late DateTime _lunes; // lunes de la semana que se está viendo
  late DateTime _diaElegido;
  bool _verMes = false; // false: franja de la semana; true: mes completo
  Set<DateTime> _guardias = {};
  List<Actividad> _actividades = [];
  List<String> _deGuardiaEseDia = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hoy = DateUtils.dateOnly(DateTime.now());
    _diaElegido = hoy;
    _lunes = _lunesDe(hoy);
    _cargarSemana();
  }

  DateTime _lunesDe(DateTime dia) => DateTime(dia.year, dia.month, dia.day - (dia.weekday - 1));

  /// Carga las visitas y guardias de la semana o del mes que se está viendo.
  Future<void> _cargarSemana() async {
    setState(() => _cargando = true);
    final desde = _verMes ? DateTime(_diaElegido.year, _diaElegido.month) : _lunes;
    final hasta = _verMes
        ? DateTime(_diaElegido.year, _diaElegido.month + 1, 0)
        : DateTime(_lunes.year, _lunes.month, _lunes.day + 6);
    try {
      final datos = await api.get('/agenda?desde=${fechaApi(desde)}&hasta=${fechaApi(hasta)}') as Map<String, dynamic>;
      setState(() {
        _guardias = (datos['guardias'] as List).map((f) => DateTime.parse(f as String)).toSet();
        _actividades =
            (datos['actividades'] as List).map((a) => Actividad.desdeJson(a as Map<String, dynamic>)).toList();
        _error = null;
      });
      await _cargarGuardiasDelDia();
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarGuardiasDelDia() async {
    try {
      final lista = await api.get('/guardias/dia/${fechaApi(_diaElegido)}') as List;
      setState(() => _deGuardiaEseDia = lista.map((u) => (u as Map<String, dynamic>)['nombre'] as String).toList());
    } on ApiError {
      setState(() => _deGuardiaEseDia = []);
    }
  }

  /// Flechas: semana anterior/siguiente o, en la vista de mes, mes anterior/siguiente.
  void _cambiarSemana(int pasos) {
    setState(() {
      if (_verMes) {
        // Mismo día en el otro mes (si no existe, el último día de ese mes)
        final otroMes = DateTime(_diaElegido.year, _diaElegido.month + pasos); // DateTime ajusta el año solo
        final ultimoDia = DateUtils.getDaysInMonth(otroMes.year, otroMes.month);
        _diaElegido = DateTime(otroMes.year, otroMes.month, _diaElegido.day.clamp(1, ultimoDia));
        _lunes = _lunesDe(_diaElegido);
      } else {
        _lunes = DateTime(_lunes.year, _lunes.month, _lunes.day + 7 * pasos);
        _diaElegido = DateTime(_diaElegido.year, _diaElegido.month, _diaElegido.day + 7 * pasos);
      }
    });
    _cargarSemana();
  }

  /// Cambia entre la franja de la semana y el mes completo.
  void _cambiarVista() {
    setState(() => _verMes = !_verMes);
    _cargarSemana();
  }

  /// Saltar a cualquier día con el calendario completo.
  Future<void> _irAFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _diaElegido,
      firstDate: DateTime(hoy.year - 2),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Ir a un día',
    );
    if (elegida == null) return;
    setState(() {
      _diaElegido = elegida;
      _lunes = _lunesDe(elegida);
    });
    _cargarSemana();
  }

  void _elegirDia(DateTime dia) {
    setState(() {
      _diaElegido = dia;
      _lunes = _lunesDe(dia);
    });
    _cargarGuardiasDelDia();
  }

  Future<void> _cambiarGuardia(bool guardia) async {
    final dia = _diaElegido;
    // Se cambia en pantalla al momento y, si falla, se deshace
    setState(() => guardia ? _guardias.add(dia) : _guardias.remove(dia));
    try {
      await api.put('/guardias/${fechaApi(dia)}', {'guardia': guardia});
      await _cargarGuardiasDelDia();
    } on ApiError catch (e) {
      setState(() => guardia ? _guardias.remove(dia) : _guardias.add(dia));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  /// Actividades de un día, ordenadas por hora (las que no tienen hora, al final).
  List<Actividad> _actividadesDe(DateTime dia) => _actividades.where((a) {
        final fecha = a.realizada ? a.fechaRealizacion : a.fechaProgramada;
        return fecha != null && DateUtils.isSameDay(fecha, dia);
      }).toList()
        ..sort((a, b) => (a.horaProgramada ?? '99:99').compareTo(b.horaProgramada ?? '99:99'));

  Future<void> _abrir(int actividadId) async {
    final cambiada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ActividadPantalla(actividadId: actividadId)),
    );
    if (cambiada == true) _cargarSemana();
  }

  /// "Programar visita": se elige sociedad → actividad pendiente sin fecha, y se abre su ficha.
  Future<void> _programar() async {
    final List<Actividad> sinFecha;
    try {
      final datos = await api.get('/agenda/pendientes') as Map<String, dynamic>;
      sinFecha = Pendientes.desdeJson(datos).actividades.where((a) => a.fechaProgramada == null).toList();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      return;
    }
    if (!mounted) return;
    final elegida = await showModalBottomSheet<Actividad>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Paleta.fondo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (contexto) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (contexto, scroll) => _ElegirActividad(sinFecha: sinFecha, scroll: scroll),
      ),
    );
    if (elegida != null) await _abrir(elegida.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargarSemana, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final hoy = DateUtils.dateOnly(DateTime.now());
    final delDia = _actividadesDe(_diaElegido);
    final tengoGuardia = _guardias.contains(_diaElegido);
    final esHoy = DateUtils.isSameDay(_diaElegido, hoy);
    final nombreDia = diasSemana[_diaElegido.weekday - 1];
    final tituloDia = esHoy ? 'Hoy, ${nombreDia.toLowerCase()} ${_diaElegido.day}' : '$nombreDia ${_diaElegido.day}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _irAFecha,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${meses[_diaElegido.month - 1]} ${_diaElegido.year}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _cambiarVista,
              tooltip: _verMes ? 'Ver la semana' : 'Ver el mes completo',
              style: IconButton.styleFrom(backgroundColor: _verMes ? Paleta.lavanda : null),
              icon: Icon(_verMes ? Icons.view_week_outlined : Icons.calendar_month_outlined, color: Paleta.morado),
            ),
            IconButton(
              onPressed: () => _cambiarSemana(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: _verMes ? 'Mes anterior' : 'Semana anterior',
            ),
            IconButton(
              onPressed: () => _cambiarSemana(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: _verMes ? 'Mes siguiente' : 'Semana siguiente',
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _verMes
              ? _Mes(
                  mes: DateTime(_diaElegido.year, _diaElegido.month),
                  elegido: _diaElegido,
                  guardias: _guardias,
                  conVisitas: (dia) => _actividadesDe(dia).isNotEmpty,
                  alPulsar: _elegirDia,
                )
              : Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _Dia(
                          fecha: DateTime(_lunes.year, _lunes.month, _lunes.day + i),
                          elegido: DateUtils.isSameDay(DateTime(_lunes.year, _lunes.month, _lunes.day + i), _diaElegido),
                          esHoy: DateUtils.isSameDay(DateTime(_lunes.year, _lunes.month, _lunes.day + i), hoy),
                          guardia: _guardias.contains(DateTime(_lunes.year, _lunes.month, _lunes.day + i)),
                          conVisitas: _actividadesDe(DateTime(_lunes.year, _lunes.month, _lunes.day + i)).isNotEmpty,
                          alPulsar: _elegirDia,
                        ),
                      ),
                  ],
                ),
        ),
        if (_cargando) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 16),
        _Guardia(
          activa: tengoGuardia,
          esHoy: esHoy,
          deGuardia: _deGuardiaEseDia,
          alCambiar: _cambiarGuardia,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(tituloDia, style: estiloSeccion)),
            Text(
              delDia.length == 1 ? '1 cita' : '${delDia.length} citas',
              style: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (delDia.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Sin visitas este día.', style: TextStyle(color: Paleta.tintaSuave))),
          )
        else
          for (final actividad in delDia) _VisitaEnLinea(actividad: actividad, alPulsar: () => _abrir(actividad.id)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _programar,
          icon: const Icon(Icons.add),
          label: const Text('Programar visita'),
        ),
      ],
    );
  }
}

/// Un día de la franja semanal: letra, número y un punto si tiene visitas.
/// Elegir qué visita programar, en el mismo orden que las carpetas: primero la sociedad y
/// después la actividad (cada una dice su centro; en su ficha se puede cambiar el centro).
class _ElegirActividad extends StatefulWidget {
  final List<Actividad> sinFecha;
  final ScrollController scroll;

  const _ElegirActividad({required this.sinFecha, required this.scroll});

  @override
  State<_ElegirActividad> createState() => _ElegirActividadState();
}

class _ElegirActividadState extends State<_ElegirActividad> {
  int? _clienteId;

  @override
  Widget build(BuildContext context) {
    // Agrupadas por sociedad, por orden alfabético
    final porCliente = <int, List<Actividad>>{};
    final ordenadas = [...widget.sinFecha]
      ..sort((a, b) => a.clienteNombre.toLowerCase().compareTo(b.clienteNombre.toLowerCase()));
    for (final a in ordenadas) {
      porCliente.putIfAbsent(a.clienteId, () => []).add(a);
    }
    final delCliente = _clienteId == null ? <Actividad>[] : [...?porCliente[_clienteId]]
      ..sort((a, b) {
        // Por centro y, dentro de cada centro, lo más antiguo primero
        final centro = (a.centroNombre ?? '').compareTo(b.centroNombre ?? '');
        return centro != 0 ? centro : a.anio.compareTo(b.anio);
      });

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            if (_clienteId != null)
              IconButton(
                tooltip: 'Atrás',
                onPressed: () => setState(() => _clienteId = null),
                icon: const Icon(Icons.arrow_back),
              ),
            const Expanded(
              child: Text('Programar visita', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (delCliente.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.folder_open_outlined, size: 18, color: Paleta.morado),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delCliente.first.clienteNombre,
                    style: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(_clienteId == null ? 'Elige la sociedad:' : 'Elige la actividad:', style: TextStyle(color: Paleta.tintaSuave)),
        const SizedBox(height: 12),
        if (widget.sinFecha.isEmpty)
          Text('Todas tus actividades pendientes ya tienen fecha.', style: TextStyle(color: Paleta.tintaSuave)),

        // 1. Sociedades
        if (_clienteId == null)
          for (final MapEntry(key: id, value: lista) in porCliente.entries)
            _Opcion(
              icono: Icons.folder_outlined,
              titulo: lista.first.clienteNombre,
              detalle: '${lista.length} ${lista.length == 1 ? 'pendiente' : 'pendientes'} sin fecha',
              atrasadas: lista.where((a) => a.atrasada).length,
              alPulsar: () => setState(() => _clienteId = id),
            ),

        // 2. Actividades de la sociedad, con su centro
        for (final a in delCliente)
          Card(
            child: ListTile(
              onTap: () => Navigator.of(context).pop(a),
              title: Text(a.tipoNombre, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                [
                  a.centroNombre ?? 'Sin centro',
                  if (a.centroCodigo != null && a.centroCodigo!.isNotEmpty) 'Nº ${a.centroCodigo}',
                  '${a.obligatoria ? 'Contrato' : 'Extra'} ${a.anio}',
                ].join(' · '),
              ),
              trailing: a.atrasada
                  ? Pastilla.atrasada(texto: '${a.anio}')
                  : Icon(Icons.chevron_right, color: Paleta.tintaSuave),
            ),
          ),
      ],
    );
  }
}

/// Una fila para elegir la sociedad, con cuántas pendientes tiene (en rojo si hay atrasadas).
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final int atrasadas;
  final VoidCallback alPulsar;

  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.atrasadas,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    final hayAtrasadas = atrasadas > 0;
    return Card(
      child: ListTile(
        onTap: alPulsar,
        leading: Icon(icono, color: hayAtrasadas ? Paleta.rojo : Paleta.morado),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          hayAtrasadas ? '$detalle · $atrasadas ${atrasadas == 1 ? 'atrasada' : 'atrasadas'}' : detalle,
          style: TextStyle(color: hayAtrasadas ? Paleta.rojo : Paleta.tintaSuave),
        ),
        trailing: Icon(Icons.chevron_right, color: Paleta.tintaSuave),
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  final DateTime fecha;
  final bool elegido;
  final bool esHoy;
  final bool guardia;
  final bool conVisitas;
  final ValueChanged<DateTime> alPulsar;

  const _Dia({
    required this.fecha,
    required this.elegido,
    required this.esHoy,
    required this.guardia,
    required this.conVisitas,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: () => alPulsar(fecha),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 78,
          decoration: BoxDecoration(
            color: elegido ? Paleta.lavanda : Paleta.blanco,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: elegido ? Paleta.morado : (esHoy ? Paleta.morado.withValues(alpha: 0.4) : Paleta.borde)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                letras[fecha.weekday - 1],
                style: TextStyle(fontSize: 13, color: elegido ? Paleta.morado : Paleta.tintaSuave, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text('${fecha.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              SizedBox(
                height: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (conVisitas)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: Paleta.morado, shape: BoxShape.circle),
                      ),
                    if (conVisitas && guardia) const SizedBox(width: 3),
                    if (guardia) Icon(Icons.shield_outlined, size: 10, color: Paleta.verde),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista de mes completo: cuadrícula de lunes a domingo con las marcas de visitas y guardias.
class _Mes extends StatelessWidget {
  final DateTime mes; // día 1 del mes
  final DateTime elegido;
  final Set<DateTime> guardias;
  final bool Function(DateTime) conVisitas;
  final ValueChanged<DateTime> alPulsar;

  const _Mes({
    required this.mes,
    required this.elegido,
    required this.guardias,
    required this.conVisitas,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final diasDelMes = DateUtils.getDaysInMonth(mes.year, mes.month);
    final huecos = mes.weekday - 1; // el lunes es la primera columna
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Paleta.blanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final letra in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(letra, style: TextStyle(color: Paleta.tintaSuave, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < huecos; i++) const SizedBox(),
              for (var d = 1; d <= diasDelMes; d++)
                _CeldaMes(
                  fecha: DateTime(mes.year, mes.month, d),
                  elegido: DateUtils.isSameDay(DateTime(mes.year, mes.month, d), elegido),
                  esHoy: DateUtils.isSameDay(DateTime(mes.year, mes.month, d), hoy),
                  guardia: guardias.contains(DateTime(mes.year, mes.month, d)),
                  conVisitas: conVisitas(DateTime(mes.year, mes.month, d)),
                  alPulsar: alPulsar,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CeldaMes extends StatelessWidget {
  final DateTime fecha;
  final bool elegido;
  final bool esHoy;
  final bool guardia;
  final bool conVisitas;
  final ValueChanged<DateTime> alPulsar;

  const _CeldaMes({
    required this.fecha,
    required this.elegido,
    required this.esHoy,
    required this.guardia,
    required this.conVisitas,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => alPulsar(fecha),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: elegido ? Paleta.lavanda : (guardia ? Paleta.verdeSuave : null),
          borderRadius: BorderRadius.circular(10),
          border: elegido
              ? Border.all(color: Paleta.morado)
              : (esHoy ? Border.all(color: Paleta.morado.withValues(alpha: 0.4)) : null),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${fecha.day}',
              style: TextStyle(fontWeight: elegido || esHoy ? FontWeight.w800 : FontWeight.w500, fontSize: 15),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: conVisitas
                  ? Container(width: 5, height: 5, decoration: BoxDecoration(color: Paleta.morado, shape: BoxShape.circle))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de la guardia del día: verde cuando está de guardia, con el interruptor.
class _Guardia extends StatelessWidget {
  final bool activa;
  final bool esHoy;
  final List<String> deGuardia;
  final ValueChanged<bool> alCambiar;

  const _Guardia({required this.activa, required this.esHoy, required this.deGuardia, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    final titulo = activa ? (esHoy ? 'Hoy estás de guardia' : 'Estás de guardia') : '¿Estás de guardia?';
    final otros = deGuardia.isEmpty ? 'Nadie de guardia este día' : 'De guardia: ${deGuardia.join(', ')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: activa ? Paleta.verdeSuave : Paleta.blanco,
        borderRadius: BorderRadius.circular(16),
        border: activa ? null : Border.all(color: Paleta.borde),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: Paleta.tinta),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(otros, style: TextStyle(color: Paleta.tintaSuave, fontSize: 13)),
              ],
            ),
          ),
          Switch(value: activa, onChanged: alCambiar),
        ],
      ),
    );
  }
}

/// Una visita en la agenda del día: hora a la izquierda y tarjeta con cliente, tipo, lugar y estado.
class _VisitaEnLinea extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback alPulsar;

  const _VisitaEnLinea({required this.actividad, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final destino = actividad.destino;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(actividad.horaProgramada ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: alPulsar,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(actividad.clienteYCentro, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(actividad.tipoNombre),
                      if (destino != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(destino, style: TextStyle(color: Paleta.tintaSuave, fontSize: 13)),
                            ),
                            IconButton(
                              tooltip: 'Abrir en Google Maps',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => abrirEnMapas(destino),
                              icon: Icon(Icons.directions_outlined, color: Paleta.morado),
                            ),
                          ],
                        )
                      else
                        const SizedBox(height: 8),
                      if (actividad.realizada)
                        const Pastilla(icono: Icons.check_circle_outline, texto: 'Realizada')
                      else if (actividad.atrasada)
                        const Pastilla.atrasada(texto: 'Actividad atrasada')
                      else
                        const Pastilla(texto: 'Programada'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
