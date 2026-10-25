import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Error que devuelve la API, con un mensaje listo para enseñar al usuario.
class ApiError implements Exception {
  final String mensaje;
  final int? codigo;

  ApiError(this.mensaje, {this.codigo});

  @override
  String toString() => mensaje;
}

/// Datos del usuario que ha iniciado sesión.
class Usuario {
  final int id;
  final String nombre;
  final String email;
  final String rol;

  Usuario({required this.id, required this.nombre, required this.email, required this.rol});

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        email: json['email'] as String,
        rol: json['rol'] as String,
      );
}

/// Un técnico, para elegir captador y redactor.
class Tecnico {
  final int id;
  final String nombre;

  Tecnico({required this.id, required this.nombre});
}

/// Se encarga de hablar con la API: iniciar sesión, guardar el token y hacer peticiones.
///
/// Es el "camarero" que lleva los pedidos a la cocina (la API) y trae la respuesta.
class Api {
  static const _claveToken = 'token';
  String? _token;

  /// Usuario que ha iniciado sesión (se rellena al entrar).
  Usuario? usuario;
  List<Tecnico>? _tecnicos;

  bool get haySesion => _token != null;

  /// Al abrir la app, recupera el token guardado (si el usuario ya había iniciado sesión).
  Future<void> cargarSesion() async {
    final preferencias = await SharedPreferences.getInstance();
    _token = preferencias.getString(_claveToken);
  }

  /// Inicia sesión con email y contraseña. Si es correcto, guarda el token en el móvil.
  Future<Usuario> login(String email, String password) async {
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('$apiUrl/auth/login'),
            // La API espera un formulario (no JSON) con los campos username y password
            body: {'username': email.trim(), 'password': password},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiError('No se puede conectar con el servidor. Revisa tu conexión.');
    }
    if (respuesta.statusCode != 200) {
      throw ApiError(_mensajeDeError(respuesta), codigo: respuesta.statusCode);
    }
    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    _token = datos['access_token'] as String;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_claveToken, _token!);
    return yo();
  }

  /// Datos del usuario que ha iniciado sesión.
  Future<Usuario> yo() async {
    final datos = await get('/auth/yo') as Map<String, dynamic>;
    final yo = Usuario.desdeJson(datos);
    usuario = yo;
    return yo;
  }

  /// Cierra la sesión y borra el token del móvil.
  Future<void> cerrarSesion() async {
    _token = null;
    usuario = null;
    _tecnicos = null;
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveToken);
  }

  /// Lista de técnicos (se pide una vez y se guarda).
  Future<List<Tecnico>> tecnicos() async {
    final guardados = _tecnicos;
    if (guardados != null) return guardados;
    final lista = await get('/tecnicos') as List;
    final tecnicos = lista.map((t) {
      final datos = t as Map<String, dynamic>;
      return Tecnico(id: datos['id'] as int, nombre: datos['nombre'] as String);
    }).toList();
    _tecnicos = tecnicos;
    return tecnicos;
  }

  /// Petición GET a la API. Devuelve el JSON ya convertido (mapa o lista).
  Future<dynamic> get(String ruta) => _enviar('GET', ruta);

  /// Petición POST a la API con un cuerpo en JSON.
  Future<dynamic> post(String ruta, [Map<String, dynamic>? cuerpo]) => _enviar('POST', ruta, cuerpo);

  /// Petición PATCH a la API con un cuerpo en JSON.
  Future<dynamic> patch(String ruta, Map<String, dynamic> cuerpo) => _enviar('PATCH', ruta, cuerpo);

  /// Petición PUT a la API con un cuerpo en JSON.
  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo) => _enviar('PUT', ruta, cuerpo);

  /// Petición DELETE a la API.
  Future<dynamic> borrar(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(String metodo, String ruta, [Map<String, dynamic>? cuerpo]) async {
    final peticion = http.Request(metodo, Uri.parse('$apiUrl$ruta'));
    if (_token != null) peticion.headers['Authorization'] = 'Bearer $_token';
    if (cuerpo != null) {
      peticion.headers['Content-Type'] = 'application/json';
      peticion.body = jsonEncode(cuerpo);
    }
    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await peticion.send().timeout(const Duration(seconds: 15)));
    } catch (_) {
      throw ApiError('No se puede conectar con el servidor. Revisa tu conexión.');
    }
    if (respuesta.statusCode == 401) {
      await cerrarSesion();
      throw ApiError('Tu sesión ha caducado. Vuelve a iniciar sesión.', codigo: 401);
    }
    if (respuesta.statusCode >= 400) {
      throw ApiError(_mensajeDeError(respuesta), codigo: respuesta.statusCode);
    }
    if (respuesta.body.isEmpty) return null;
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  /// Saca el mensaje de error que envía la API (campo "detail").
  String _mensajeDeError(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final detalle = datos is Map ? datos['detail'] : null;
      if (detalle is String) return detalle;
      if (detalle is List && detalle.isNotEmpty) return 'Revisa los datos introducidos.';
    } catch (_) {
      // la respuesta no era JSON
    }
    return 'Ha ocurrido un error (${respuesta.statusCode}).';
  }
}

/// Una única instancia para toda la app.
final api = Api();
