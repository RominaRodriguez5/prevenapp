/// Una sociedad (cliente) del técnico: la carpeta de la pestaña Clientes. Sus centros de trabajo
/// son los que tienen nº de cliente, CIF y dirección (ver [Centro]).
class Cliente {
  final int id;
  final String nombre;
  final String? codigo;
  final String? cif;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? personaContacto;
  final String? notas;
  // Contadores de la carpeta: actividades que le faltan (atrasadas = de años anteriores) y hechas
  final int faltan;
  final int atrasadas;
  final int hechas;
  final int numCentros;

  Cliente({
    required this.id,
    required this.nombre,
    this.codigo,
    this.cif,
    this.direccion,
    this.telefono,
    this.email,
    this.personaContacto,
    this.notas,
    this.faltan = 0,
    this.atrasadas = 0,
    this.hechas = 0,
    this.numCentros = 0,
  });

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        codigo: json['codigo'] as String?,
        cif: json['cif'] as String?,
        direccion: json['direccion'] as String?,
        telefono: json['telefono'] as String?,
        email: json['email'] as String?,
        personaContacto: json['persona_contacto'] as String?,
        notas: json['notas'] as String?,
        faltan: json['faltan'] as int? ?? 0,
        atrasadas: json['atrasadas'] as int? ?? 0,
        hechas: json['hechas'] as int? ?? 0,
        numCentros: json['num_centros'] as int? ?? 0,
      );
}

/// Un centro de trabajo de una sociedad (subcarpeta dentro de la carpeta de la sociedad).
/// Cada centro es un cliente en sí: tiene su nº de cliente, su CIF y su dirección.
class Centro {
  final int id;
  final int clienteId;
  final String nombre;
  final String? codigo; // nº de cliente
  final String? cif;
  final String? direccion;
  final int faltan;
  final int atrasadas;
  final int hechas;

  Centro({
    required this.id,
    required this.clienteId,
    required this.nombre,
    this.codigo,
    this.cif,
    this.direccion,
    this.faltan = 0,
    this.atrasadas = 0,
    this.hechas = 0,
  });

  factory Centro.desdeJson(Map<String, dynamic> json) => Centro(
        id: json['id'] as int,
        clienteId: json['cliente_id'] as int,
        nombre: json['nombre'] as String,
        codigo: json['codigo'] as String?,
        cif: json['cif'] as String?,
        direccion: json['direccion'] as String?,
        faltan: json['faltan'] as int? ?? 0,
        atrasadas: json['atrasadas'] as int? ?? 0,
        hechas: json['hechas'] as int? ?? 0,
      );
}

/// Un tipo de actividad del catálogo (Evaluación de riesgos, Formación...).
class TipoActividad {
  final int id;
  final String nombre;

  TipoActividad({required this.id, required this.nombre});

  factory TipoActividad.desdeJson(Map<String, dynamic> json) =>
      TipoActividad(id: json['id'] as int, nombre: json['nombre'] as String);
}

/// Una línea del contrato: "este cliente necesita esta actividad cada año".
class LineaContrato {
  final int id;
  final int tipoActividadId;
  final String tipoNombre;
  final int desdeAnio;
  final bool activa;

  LineaContrato({
    required this.id,
    required this.tipoActividadId,
    required this.tipoNombre,
    required this.desdeAnio,
    required this.activa,
  });

  factory LineaContrato.desdeJson(Map<String, dynamic> json) => LineaContrato(
        id: json['id'] as int,
        tipoActividadId: json['tipo_actividad_id'] as int,
        tipoNombre: json['tipo_nombre'] as String,
        desdeAnio: json['desde_anio'] as int,
        activa: json['activa'] as bool,
      );
}
