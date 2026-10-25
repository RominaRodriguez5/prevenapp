import 'package:flutter/material.dart';

import '../modelos/actividad.dart';
import '../servicios/api.dart';
import '../tema.dart';
import '../utilidades/formato.dart';
import 'actividad.dart';
import 'lista_actividades.dart';

/// Inicio: el día del técnico. Atrasadas, visitas de hoy, próxima visita y lo que queda por hacer.
class PendientesPantalla extends StatefulWidget {
  const PendientesPantalla({super.key});

  @override
  State<PendientesPantalla> createState() => _PendientesPantallaState();
}

class _DatosInicio {
  final Pendientes pendientes;
  final List<Actividad> hechasEsteMes;

  _DatosInicio(this.pendientes, this.hechasEsteMes);
}

class _PendientesPantallaState extends State<PendientesPantalla> {
  late Future<_DatosInicio> _datos;
  bool _verTodasAtrasadas = false;
  // Filtro elegido al pulsar un contador: null (sin filtro), 'atrasadas', 'hoy' o 'hechas'
  String? _filtro;

  /// Pulsar un contador activa su filtro; pulsarlo otra vez lo quita.
  void _filtrar(String filtro) => setState(() => _filtro = _filtro == filtro ? null : filtro);

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<_DatosInicio> _cargar() async {
    final hoy = DateTime.now();
    final pendientes = await api.get('/agenda/pendientes') as Map<String, dynamic>;
    final historial = await api.get('/historial?anio=${hoy.year}') as Map<String, dynamic>;
    final mes = (historial['meses'] as List)[hoy.month - 1] as Map<String, dynamic>;
    final hechas = (mes['actividades'] as List)
        .map((a) => Actividad.desdeJson(a as Map<String, dynamic>))
        .toList()
        .reversed // las más recientes primero
        .toList();
    return _DatosInicio(Pendientes.desdeJson(pendientes), hechas);
  }

  Future<void> _recargar() async {
    final nuevos = _cargar();
    setState(() => _datos = nuevos);
    await nuevos;
  }

  /// Tarjetas de la lista filtrada (o un mensaje si está vacía).
  List<Widget> _listaFiltrada(List<Actividad> actividades, String textoVacio) {
    if (actividades.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(textoVacio, textAlign: TextAlign.center, style: TextStyle(color: Paleta.tintaSuave, fontSize: 16)),
        ),
      ];
    }
    return [
      for (final actividad in actividades) TarjetaActividadLista(actividad: actividad, alPulsar: () => _abrir(actividad)),
    ];
  }

  Future<void> _abrir(Actividad actividad) async {
    final cambiada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ActividadPantalla(actividadId: actividad.id)),
    );
    // Si se ha hecho el check o se ha programado, se vuelve a cargar
    if (cambiada == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosInicio>(
      future: _datos,
      builder: (context, estado) {
        if (estado.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (estado.hasError) {
          return _Error(mensaje: estado.error.toString(), alReintentar: _recargar);
        }
        final datos = estado.data!.pendientes;
        final hoy = DateUtils.dateOnly(DateTime.now());
        final atrasadas = datos.actividades.where((a) => a.atrasada).toList();
        final resto = datos.actividades.where((a) => !a.atrasada).toList();
        final paraHoy = datos.actividades.where((a) {
          final fecha = a.fechaProgramada;
          return fecha != null && DateUtils.isSameDay(fecha, hoy);
        }).toList()
          ..sort((a, b) => (a.horaProgramada ?? '99:99').compareTo(b.horaProgramada ?? '99:99'));
        final hechas = estado.data!.hechasEsteMes;
        // Próxima visita: la programada más cercana desde hoy (por fecha y hora)
        final proximas = datos.actividades.where((a) {
          final fecha = a.fechaProgramada;
          return fecha != null && !fecha.isBefore(hoy);
        }).toList()
          ..sort((a, b) {
            final porFecha = a.fechaProgramada!.compareTo(b.fechaProgramada!);
            if (porFecha != 0) return porFecha;
            return (a.horaProgramada ?? '99:99').compareTo(b.horaProgramada ?? '99:99');
          });
        final atrasadasVisibles = _verTodasAtrasadas ? atrasadas : atrasadas.take(1).toList();

        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '${fechaLarga(hoy)} de ${hoy.year}',
                style: TextStyle(fontSize: 16, color: Paleta.tintaSuave),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Contador(
                      icono: Icons.warning_amber_rounded,
                      valor: atrasadas.length,
                      texto: 'Atrasadas',
                      fondo: Paleta.rojoSuave,
                      color: Paleta.rojo,
                      elegido: _filtro == 'atrasadas',
                      alPulsar: () => _filtrar('atrasadas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Contador(
                      icono: Icons.calendar_today_outlined,
                      valor: paraHoy.length,
                      texto: 'Para hoy',
                      fondo: Paleta.blanco,
                      color: Paleta.tinta,
                      elegido: _filtro == 'hoy',
                      alPulsar: () => _filtrar('hoy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Contador(
                      icono: Icons.check_circle_outline,
                      valor: hechas.length,
                      texto: 'Hechas este mes',
                      fondo: Paleta.lavandaSuave,
                      color: Paleta.morado,
                      elegido: _filtro == 'hechas',
                      alPulsar: () => _filtrar('hechas'),
                    ),
                  ),
                ],
              ),
              if (_filtro != null) ...[
                const SizedBox(height: 24),
                _TituloSeccion(
                  texto: switch (_filtro) {
                    'atrasadas' => 'Atrasadas',
                    'hoy' => 'Para hoy',
                    _ => 'Hechas en ${meses[hoy.month - 1].toLowerCase()}',
                  },
                  accion: 'Quitar filtro',
                  alPulsar: () => setState(() => _filtro = null),
                ),
                ..._listaFiltrada(
                  switch (_filtro) {
                    'atrasadas' => atrasadas,
                    'hoy' => paraHoy,
                    _ => hechas,
                  },
                  switch (_filtro) {
                    'atrasadas' => '¡Ninguna atrasada! Todo al día.',
                    'hoy' => 'No tienes visitas programadas para hoy.',
                    _ => 'Todavía no has realizado ninguna actividad este mes.',
                  },
                ),
              ] else ...[
                if (atrasadas.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _TituloSeccion(
                    texto: 'Primero, lo pendiente',
                    accion: atrasadas.length > 1
                        ? (_verTodasAtrasadas ? 'Ver menos' : 'Ver las ${atrasadas.length}')
                        : null,
                    alPulsar: () => setState(() => _verTodasAtrasadas = !_verTodasAtrasadas),
                  ),
                  for (final actividad in atrasadasVisibles)
                    _TarjetaAtrasada(actividad: actividad, alPulsar: () => _abrir(actividad)),
                ],
                if (proximas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _TituloSeccion(texto: 'Tu próxima visita'),
                  _ProximaVisita(actividad: proximas.first, alPulsar: () => _abrir(proximas.first)),
                ],
                if (datos.clientesSinVisitarAnioAnterior.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SinVisitar(clientes: datos.clientesSinVisitarAnioAnterior, anio: datos.anioActual - 1),
                ],
                const SizedBox(height: 16),
                if (datos.actividades.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Paleta.lavandaSuave,
                          child: Icon(Icons.done_all, size: 36, color: Paleta.morado),
                        ),
                        SizedBox(height: 14),
                        Text('Todo al día', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text('No tienes nada pendiente.', style: TextStyle(color: Paleta.tintaSuave)),
                      ],
                    ),
                  )
                else if (resto.isNotEmpty) ...[
                  _TituloSeccion(texto: 'Por hacer en ${datos.anioActual}', accion: '${resto.length}'),
                  for (final actividad in resto) _TarjetaActividad(actividad: actividad, alPulsar: () => _abrir(actividad)),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  final String? accion;
  final VoidCallback? alPulsar;

  const _TituloSeccion({required this.texto, this.accion, this.alPulsar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: estiloSeccion)),
          if (accion != null)
            alPulsar == null
                ? Text(accion!, style: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w700))
                : InkWell(
                    onTap: alPulsar,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(accion!, style: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w700)),
                    ),
                  ),
        ],
      ),
    );
  }
}

/// Uno de los tres contadores de arriba (Atrasadas, Para hoy, Hechas este mes).
/// Al pulsarlo se filtra Inicio para ver solo esas actividades.
class _Contador extends StatelessWidget {
  final IconData icono;
  final int valor;
  final String texto;
  final Color fondo;
  final Color color;
  final bool elegido;
  final VoidCallback alPulsar;

  const _Contador({
    required this.icono,
    required this.valor,
    required this.texto,
    required this.fondo,
    required this.color,
    required this.elegido,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Elegido: borde grueso del color del contador
        side: elegido
            ? BorderSide(color: color, width: 2.5)
            : (fondo == Paleta.blanco ? BorderSide(color: Paleta.borde) : BorderSide.none),
      ),
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 124,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 22),
                  const Spacer(),
                  Icon(
                    elegido ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: color.withValues(alpha: elegido ? 1 : 0.5),
                    size: 18,
                  ),
                ],
              ),
              const Spacer(),
              Text('$valor', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color, height: 1)),
              const SizedBox(height: 4),
              Text(texto, maxLines: 2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Actividad atrasada: tarjeta roja suave con "ATRASADA · 2024" y "Resolver actividad".
class _TarjetaAtrasada extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback alPulsar;

  const _TarjetaAtrasada({required this.actividad, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Paleta.rojoSuave,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Paleta.rojoBorde),
        ),
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Paleta.rojo, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ATRASADA · ${actividad.anio}',
                        style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Paleta.rojo),
                  ],
                ),
                const SizedBox(height: 10),
                Text(actividad.tipoNombre, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${actividad.clienteYCentro} · Contrato ${actividad.anio}',
                  style: TextStyle(color: Paleta.tintaSuave),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 18, color: Paleta.rojo),
                    SizedBox(width: 6),
                    Text('Resolver actividad', style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La próxima visita: hora grande a la izquierda, cliente y dirección.
class _ProximaVisita extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback alPulsar;

  const _ProximaVisita({required this.actividad, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final fecha = actividad.fechaProgramada!;
    final esHoy = DateUtils.isSameDay(fecha, DateTime.now());
    return Card(
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actividad.horaProgramada ?? '--:--', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
                    Text(
                      esHoy ? 'Hoy' : '${fecha.day} ${mesesCortos[fecha.month - 1].toLowerCase()}',
                      style: TextStyle(color: Paleta.tintaSuave),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actividad.clienteYCentro, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(actividad.tipoNombre, style: TextStyle(color: Paleta.tintaSuave)),
                    if (actividad.destino != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: Paleta.morado),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              actividad.destino!,
                              style: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Aviso: clientes que no se visitaron el año pasado.
class _SinVisitar extends StatelessWidget {
  final List<String> clientes;
  final int anio;

  const _SinVisitar({required this.clientes, required this.anio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Paleta.lavandaSuave, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Paleta.morado, size: 20),
              const SizedBox(width: 8),
              Text('Sin visitar en $anio', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final cliente in clientes) Pastilla(texto: cliente, fondo: Paleta.blanco)],
          ),
        ],
      ),
    );
  }
}

/// Actividad del año que queda por hacer.
class _TarjetaActividad extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback alPulsar;

  const _TarjetaActividad({required this.actividad, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    final programada = actividad.fechaProgramada;
    return Card(
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actividad.clienteYCentro, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(actividad.tipoNombre, style: TextStyle(color: Paleta.tintaSuave)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (programada != null)
                          Pastilla(
                            icono: Icons.event,
                            texto: actividad.horaProgramada == null
                                ? 'Visita ${fechaTexto(programada)}'
                                : 'Visita ${fechaTexto(programada)} · ${actividad.horaProgramada}',
                          )
                        else
                          Pastilla(texto: 'Sin fecha', fondo: Paleta.fondo, letra: Paleta.tintaSuave),
                        if (!actividad.obligatoria) const Pastilla(texto: 'Extra'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Paleta.tintaSuave),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const _Error({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Paleta.tintaSuave),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: alReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
