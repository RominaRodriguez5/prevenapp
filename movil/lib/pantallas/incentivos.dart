import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';

/// Incentivos del cuatrimestre (en forma de "ticket") e historial de actividades del año.
class IncentivosPantalla extends StatefulWidget {
  const IncentivosPantalla({super.key});

  @override
  State<IncentivosPantalla> createState() => _IncentivosPantallaState();
}

class _IncentivosPantallaState extends State<IncentivosPantalla> with AutomaticKeepAliveClientMixin {
  late int _anio;
  late int _cuatrimestre;
  late int _mesElegido; // 1-12
  Map<String, dynamic>? _incentivos;
  int _tecnicoId = 0;
  // Actividades realizadas de cada mes (posición 0 = enero)
  List<List<Actividad>> _porMes = List.generate(12, (_) => []);
  bool _cargando = true;
  String? _error;

  // Mantiene la pantalla viva (no se recarga cada vez que se dibuja)
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _anio = hoy.year;
    _cuatrimestre = (hoy.month - 1) ~/ 4 + 1;
    _mesElegido = hoy.month;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final incentivos =
          await api.get('/incentivos?anio=$_anio&cuatrimestre=$_cuatrimestre') as Map<String, dynamic>;
      final historial = await api.get('/historial?anio=$_anio') as Map<String, dynamic>;
      setState(() {
        _incentivos = incentivos;
        _tecnicoId = historial['tecnico_id'] as int;
        _porMes = (historial['meses'] as List)
            .map((m) => ((m as Map<String, dynamic>)['actividades'] as List)
                .map((a) => Actividad.desdeJson(a as Map<String, dynamic>))
                .toList())
            .toList();
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarCuatrimestre(int cuatrimestre) {
    setState(() {
      _cuatrimestre = cuatrimestre;
      // Al cambiar de cuatrimestre se elige su primer mes en el historial
      _mesElegido = (cuatrimestre - 1) * 4 + 1;
    });
    _cargar();
  }

  void _cambiarAnio(int desplazamiento) {
    setState(() => _anio += desplazamiento);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final datos = _incentivos;
    final delMes = _porMes[_mesElegido - 1];
    final totalAnio = _porMes.fold<int>(0, (suma, mes) => suma + mes.length);
    final incentivoMes = delMes.fold<double>(0, (suma, a) => suma + a.incentivoDe(_tecnicoId));
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _cambiarAnio(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Año anterior'),
              Expanded(
                child: Text(
                  '$_anio',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: () => _cambiarAnio(1), icon: const Icon(Icons.chevron_right), tooltip: 'Año siguiente'),
            ],
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Ene–Abr')),
              ButtonSegment(value: 2, label: Text('May–Ago')),
              ButtonSegment(value: 3, label: Text('Sep–Dic')),
            ],
            selected: {_cuatrimestre},
            showSelectedIcon: false,
            onSelectionChanged: (seleccion) => _cambiarCuatrimestre(seleccion.first),
          ),
          if (_cargando) const LinearProgressIndicator() else const SizedBox(height: 4),
          const SizedBox(height: 16),
          if (datos != null) _Ticket(datos: datos),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('Historial', style: estiloSeccion),
              const Spacer(),
              Text(
                '$totalAnio ${totalAnio == 1 ? 'actividad' : 'actividades'} en $_anio',
                style: TextStyle(color: Paleta.tintaSuave),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: totalAnio == 0
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 40, color: Paleta.tintaSuave),
                          SizedBox(height: 8),
                          Text(
                            'Aquí verás, mes a mes, las actividades que has realizado.\n'
                            'Aparecen cuando haces el check de una actividad.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Paleta.tintaSuave),
                          ),
                        ],
                      ),
                    )
                  : _Barras(
                      valores: _porMes.map((m) => m.length).toList(),
                      cuatrimestre: _cuatrimestre,
                      mesElegido: _mesElegido,
                      alElegir: (mes) => setState(() => _mesElegido = mes),
                    ),
            ),
          ),
          if (totalAnio > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${meses[_mesElegido - 1]} $_anio',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (delMes.isNotEmpty)
                  Text(euros(incentivoMes), style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.morado)),
              ],
            ),
            const SizedBox(height: 8),
            if (delMes.isEmpty)
              Text('Ninguna actividad realizada este mes.', style: TextStyle(color: Paleta.tintaSuave))
            else
              for (final a in delMes) _FilaHistorial(actividad: a, tecnicoId: _tecnicoId),
          ],
        ],
      ),
    );
  }
}

/// Una actividad realizada en el historial: fecha, cliente, papel del técnico e importe.
class _FilaHistorial extends StatelessWidget {
  final Actividad actividad;
  final int tecnicoId;

  const _FilaHistorial({required this.actividad, required this.tecnicoId});

  @override
  Widget build(BuildContext context) {
    final papeles = [
      if (actividad.captadorId == tecnicoId) 'Captador',
      if (actividad.redactorId == tecnicoId) 'Redactor',
    ].join(' + ');
    final fecha = actividad.fechaRealizacion;
    return Card(
      child: ListTile(
        leading: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: Paleta.papel, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fecha == null ? '' : '${fecha.day}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(fecha == null ? '' : mesesCortos[fecha.month - 1], style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        title: Text(actividad.clienteYCentro, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${actividad.tipoNombre}\n$papeles · ${actividad.codigoPresupuesto ?? ''}'),
        isThreeLine: true,
        trailing: Text(
          euros(actividad.incentivoDe(tecnicoId)),
          style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.sello),
        ),
      ),
    );
  }
}

/// Incentivos del cuatrimestre: tarjeta verde con el total, "Cómo se calcula" y las actividades.
class _Ticket extends StatelessWidget {
  final Map<String, dynamic> datos;

  const _Ticket({required this.datos});

  @override
  Widget build(BuildContext context) {
    final captador = datos['como_captador'] as Map<String, dynamic>;
    final redactor = datos['como_redactor'] as Map<String, dynamic>;
    final total = (datos['total'] as num).toDouble();
    final actividades = (datos['actividades'] as List)
        .map((a) => Actividad.desdeJson(a as Map<String, dynamic>))
        .toList();
    final desde = DateTime.parse(datos['desde'] as String);
    final hasta = DateTime.parse(datos['hasta'] as String);
    final numCaptador = captador['numero'] as int;
    final numRedactor = redactor['numero'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaResumen(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Acumulado este cuatrimestre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Icon(Icons.account_balance_wallet_outlined, color: Paleta.tinta),
                ],
              ),
              const SizedBox(height: 10),
              Text(euros(total), style: estiloCifra),
              const SizedBox(height: 8),
              Text(
                '${fechaTexto(desde)} – ${fechaTexto(hasta)} · 8 % del presupuesto sin IVA',
                style: TextStyle(color: Paleta.tintaSuave, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Cómo se calcula', style: estiloSeccion),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _LineaTicket(
                icono: Icons.handshake_outlined,
                texto: 'Como captador',
                detalle: '$numCaptador ${numCaptador == 1 ? 'actividad' : 'actividades'} conseguidas',
                importe: (captador['total'] as num).toDouble(),
              ),
              const Divider(indent: 16, endIndent: 16),
              _LineaTicket(
                icono: Icons.assignment_turned_in_outlined,
                texto: 'Como redactor',
                detalle: '$numRedactor ${numRedactor == 1 ? 'actividad' : 'actividades'} realizadas',
                importe: (redactor['total'] as num).toDouble(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (actividades.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Actividades del cuatrimestre', style: estiloSeccion),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                  for (final a in actividades)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              a.fechaRealizacion == null ? '' : fechaTexto(a.fechaRealizacion!).substring(0, 5),
                              style: TextStyle(color: Paleta.tintaSuave),
                            ),
                          ),
                          Expanded(child: Text(a.clienteYCentro, overflow: TextOverflow.ellipsis)),
                          Text(a.codigoPresupuesto ?? '', style: TextStyle(color: Paleta.tintaSuave, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ] else
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Todavía no hay actividades realizadas en este cuatrimestre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Paleta.tintaSuave),
            ),
          ),
      ],
    );
  }
}

class _LineaTicket extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String detalle;
  final double importe;

  const _LineaTicket({required this.icono, required this.texto, required this.detalle, required this.importe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icono, color: Paleta.tinta),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(detalle, style: TextStyle(color: Paleta.tintaSuave, fontSize: 13)),
              ],
            ),
          ),
          Text(euros(importe), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Gráfico de barras: actividades realizadas cada mes. Se puede pulsar un mes para ver su detalle.
class _Barras extends StatelessWidget {
  final List<int> valores;
  final int cuatrimestre;
  final int mesElegido;
  final ValueChanged<int> alElegir;

  const _Barras({
    required this.valores,
    required this.cuatrimestre,
    required this.mesElegido,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<int>(0, (a, b) => a > b ? a : b);
    const alto = 120.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 12; i++)
          Expanded(
            child: InkWell(
              onTap: () => alElegir(i + 1),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 16,
                    child: valores[i] > 0
                        ? Text('${valores[i]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
                        : null,
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: maximo == 0 ? 4 : 4 + (alto - 4) * valores[i] / maximo,
                    decoration: BoxDecoration(
                      color: i + 1 == mesElegido
                          ? Paleta.morado
                          : ((i ~/ 4 + 1) == cuatrimestre ? Paleta.lavanda : Paleta.borde),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mesesCortos[i][0],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i + 1 == mesElegido ? FontWeight.w900 : FontWeight.normal,
                      color: i + 1 == mesElegido ? Paleta.tinta : Paleta.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
