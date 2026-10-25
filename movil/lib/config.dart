import 'package:flutter/foundation.dart';

/// Dirección de la API indicada al compilar, para instalar la app en un móvil de verdad:
///   flutter build apk --dart-define=API_URL=http://192.168.1.50:8000
/// (con la IP del ordenador donde está Docker). Si no se indica, queda vacía.
const String _apiIndicada = String.fromEnvironment('API_URL');

/// Dirección de la API (el backend en Python).
///
/// - Si se ha indicado API_URL al compilar (móvil de verdad), se usa esa.
/// - En Chrome (web), la API está en el mismo ordenador: localhost.
/// - En el emulador de Android, "localhost" es el propio emulador; para llegar
///   al ordenador se usa la dirección especial 10.0.2.2.
String get apiUrl {
  if (_apiIndicada.isNotEmpty) return _apiIndicada;
  if (kIsWeb) return 'http://localhost:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

/// Dominio del email de la empresa. El técnico solo escribe su usuario (p. ej. "ana")
/// y la app añade "@previs.es". Si escribe el email completo, se respeta tal cual.
/// Para usar la app en otra empresa basta con cambiar esta línea.
const String dominioEmpresa = 'previs.es';

/// Convierte lo que escribe el usuario en un email completo.
String emailCompleto(String texto) {
  final limpio = texto.trim().toLowerCase();
  return limpio.contains('@') ? limpio : '$limpio@$dominioEmpresa';
}
