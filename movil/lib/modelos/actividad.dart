/// Una actividad tal como la devuelve la API.
class Actividad {
  final int id;
  final int clienteId;
  final String clienteNombre;
  final String? clienteDireccion;
  final int? centroId;
  final String? centroNombre;
  final String? centroCodigo; // nº de cliente del centro
  final String tipoNombre;
  final int anio;
  final bool obligatoria;
  final String estado; // pendiente, programada o realizada
  final DateTime? fechaProgramada;
  final String? horaProgramada; // "09:30"
  final String? lugar;
  final DateTime? fechaRealizacion;
  final String? codigoPresupuesto;
  final double? importePresupuesto;
  final int? captadorId;
  final String? captadorNombre;
  final int? redactorId;
  final String? redactorNombre;
  final double? importeCaptador;
  final double? importeRedactor;
  final String? notas;
  final bool atrasada;

  Actividad({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteDireccion,
    this.centroId,
    this.centroNombre,
    this.centroCodigo,
    required this.tipoNombre,
    required this.anio,
    required this.obligatoria,
    required this.estado,
    this.fechaProgramada,
    this.horaProgramada,
    this.lugar,
    this.fechaRealizacion,
    this.codigoPresupuesto,
    this.importePresupuesto,
    this.captadorId,
    this.captadorNombre,
    this.redactorId,
    this.redactorNombre,
    this.importeCaptador,
    this.importeRedactor,
    this.notas,
    required this.atrasada,
  });

  bool get realizada => estado == 'realizada';

  /// Cliente y centro de trabajo: "Hotel Brisa · Lavandería central".
  /// Si es el "Centro principal", basta con el nombre del cliente.
  String get clienteYCentro =>
      (centroNombre == null || centroNombre == 'Centro principal') ? clienteNombre : '$clienteNombre · $centroNombre';

  /// Dónde hay que ir: el lugar de la visita o, si no se indicó, la dirección del cliente.
  String? get destino => (lugar != null && lugar!.isNotEmpty) ? lugar : clienteDireccion;

  /// Lo que cobra un técnico concreto por esta actividad (como captador, redactor o ambos).
  double incentivoDe(int tecnicoId) =>
      (captadorId == tecnicoId ? importeCaptador ?? 0.0 : 0.0) + (redactorId == tecnicoId ? importeRedactor ?? 0.0 : 0.0);

  factory Actividad.desdeJson(Map<String, dynamic> json) => Actividad(
        id: json['id'] as int,
        clienteId: json['cliente_id'] as int,
        clienteNombre: json['cliente_nombre'] as String,
        clienteDireccion: json['cliente_direccion'] as String?,
        centroId: json['centro_id'] as int?,
        centroNombre: json['centro_nombre'] as String?,
        centroCodigo: json['centro_codigo'] as String?,
        tipoNombre: json['tipo_nombre'] as String,
        anio: json['anio'] as int,
        obligatoria: json['obligatoria'] as bool,
        estado: json['estado'] as String,
        fechaProgramada: _fecha(json['fecha_programada']),
        // La API manda "09:30:00"; nos quedamos con "09:30"
        horaProgramada: (json['hora_programada'] as String?)?.substring(0, 5),
        lugar: json['lugar'] as String?,
        fechaRealizacion: _fecha(json['fecha_realizacion']),
        codigoPresupuesto: json['codigo_presupuesto'] as String?,
        importePresupuesto: (json['importe_presupuesto'] as num?)?.toDouble(),
        captadorId: json['captador_id'] as int?,
        captadorNombre: json['captador_nombre'] as String?,
        redactorId: json['redactor_id'] as int?,
        redactorNombre: json['redactor_nombre'] as String?,
        importeCaptador: (json['importe_captador'] as num?)?.toDouble(),
        importeRedactor: (json['importe_redactor'] as num?)?.toDouble(),
        notas: json['notas'] as String?,
        atrasada: json['atrasada'] as bool? ?? false,
      );

  static DateTime? _fecha(dynamic valor) => valor == null ? null : DateTime.parse(valor as String);
}

/// Respuesta de /agenda/pendientes.
class Pendientes {
  final int anioActual;
  final int total;
  final int delAnioActual;
  final int deAniosAnteriores;
  final List<Actividad> actividades;
  final List<String> clientesSinVisitarAnioAnterior;

  Pendientes({
    required this.anioActual,
    required this.total,
    required this.delAnioActual,
    required this.deAniosAnteriores,
    required this.actividades,
    required this.clientesSinVisitarAnioAnterior,
  });

  factory Pendientes.desdeJson(Map<String, dynamic> json) => Pendientes(
        anioActual: json['anio_actual'] as int,
        total: json['total'] as int,
        delAnioActual: json['del_anio_actual'] as int,
        deAniosAnteriores: json['de_anios_anteriores'] as int,
        actividades: (json['actividades'] as List)
            .map((a) => Actividad.desdeJson(a as Map<String, dynamic>))
            .toList(),
        clientesSinVisitarAnioAnterior:
            (json['clientes_sin_visitar_anio_anterior'] as List).map((c) => c as String).toList(),
      );
}
