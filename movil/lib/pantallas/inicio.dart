import 'package:flutter/material.dart';

import '../servicios/api.dart';
import '../tema.dart';
import 'calendario.dart';
import 'clientes.dart';
import 'incentivos.dart';
import 'login.dart';
import 'pendientes.dart';

/// Pantalla principal con cuatro pestañas abajo: Inicio, Clientes, Calendario y Mi actividad
/// (Mi actividad = incentivos e historial de actividades hechas).
class InicioPantalla extends StatefulWidget {
  final Usuario usuario;

  const InicioPantalla({super.key, required this.usuario});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _pestana = 0;
  // Cada vez que se entra en una pestaña se suma 1: así se vuelve a crear y recarga sus datos
  final _recargas = [0, 0, 0, 0];

  Future<void> _salir() async {
    await api.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPantalla()));
  }

  /// Iniciales del usuario para el círculo de arriba a la derecha ("Marta López" → "ML").
  String get _iniciales {
    final partes = widget.usuario.nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primera = partes.first[0];
    final segunda = partes.length > 1 ? partes[1][0] : '';
    return '$primera$segunda'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario.nombre.split(' ').first;
    final cabeceras = [
      ('PrevenApp · tu día, bajo control', 'Hola, $nombre'),
      ('Cartera de clientes', 'Mis clientes'),
      ('Visitas y guardias', 'Mi calendario'),
      ('Incentivos e historial', 'Mi actividad'),
    ];
    final (sobretitulo, titulo) = cabeceras[_pestana];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Cabecera(sobretitulo: sobretitulo, titulo: titulo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              tooltip: 'Mi cuenta',
              onSelected: (opcion) => opcion == 'modo' ? cambiarModoOscuro() : _salir(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(widget.usuario.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                PopupMenuItem(
                  value: 'modo',
                  child: Row(
                    children: [
                      Icon(modoOscuro.value ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(modoOscuro.value ? 'Modo claro' : 'Modo oscuro'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'salir',
                  child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 10), Text('Cerrar sesión')]),
                ),
              ],
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Paleta.lavanda,
                foregroundColor: Paleta.morado,
                child: Text(_iniciales, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
      // En pantallas anchas (Chrome, tablet) el contenido no pasa de 640 píxeles,
      // para que se vea como en el móvil
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: IndexedStack(
            index: _pestana,
            children: [
              PendientesPantalla(key: ValueKey('inicio-${_recargas[0]}')),
              ClientesPantalla(key: ValueKey('clientes-${_recargas[1]}')),
              CalendarioPantalla(key: ValueKey('agenda-${_recargas[2]}')),
              IncentivosPantalla(key: ValueKey('actividad-${_recargas[3]}')),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() {
          _pestana = i;
          _recargas[i]++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_outlined),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_outlined),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_outlined),
            label: 'Mi actividad',
          ),
        ],
      ),
    );
  }
}
