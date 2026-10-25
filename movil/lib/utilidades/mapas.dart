/// Abrir una dirección en Google Maps.
library;

import 'package:url_launcher/url_launcher.dart';

/// Abre Google Maps (la app en el móvil o la web en el ordenador) con la dirección,
/// para ver dónde está y cómo llegar. Devuelve false si no se pudo abrir.
Future<bool> abrirEnMapas(String direccion) {
  final enlace = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': direccion});
  return launchUrl(enlace, mode: LaunchMode.externalApplication);
}
