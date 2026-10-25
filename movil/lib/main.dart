import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pantallas/inicio.dart';
import 'pantallas/login.dart';
import 'servicios/api.dart';
import 'tema.dart';

/// Punto de entrada de la app PrevenApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Modo oscuro: el que eligió el usuario o, si nunca lo ha cambiado, el del móvil
  final preferencias = await SharedPreferences.getInstance();
  final guardado = preferencias.getBool(claveModoOscuro);
  final delMovil = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  modoOscuro.value = guardado ?? delMovil;
  runApp(const PrevenApp());
}

class PrevenApp extends StatefulWidget {
  const PrevenApp({super.key});

  @override
  State<PrevenApp> createState() => _PrevenAppState();
}

class _PrevenAppState extends State<PrevenApp> with SingleTickerProviderStateMixin {
  // Para la transición entre modo claro y oscuro
  final _pantalla = GlobalKey();
  late final AnimationController _fundido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  ui.Image? _foto;

  @override
  void initState() {
    super.initState();
    modoOscuro.addListener(_alCambiarModo);
    antesDeCambiarModo = _hacerFoto;
  }

  @override
  void dispose() {
    modoOscuro.removeListener(_alCambiarModo);
    antesDeCambiarModo = null;
    _fundido.dispose();
    _foto?.dispose();
    super.dispose();
  }

  /// Antes de cambiar de modo: "foto" de la pantalla tal como está, que se pone encima.
  Future<void> _hacerFoto() async {
    try {
      final limite = _pantalla.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (limite == null) return;
      // Foto a resolución completa de la pantalla, para que el fundido se vea nítido
      final foto = await limite.toImage(pixelRatio: View.of(context).devicePixelRatio);
      _foto?.dispose();
      setState(() => _foto = foto);
      _fundido.value = 1;
      // Esperar a que la foto ya se esté mostrando antes de cambiar los colores
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {
      // Si no se puede hacer la foto (o tarda demasiado), se cambia de modo sin transición
    }
  }

  /// Al cambiar de modo se vuelven a dibujar todas las pantallas con los colores nuevos,
  /// sin crearlas de cero (se mantiene la pantalla, la pestaña, los filtros...). Mientras,
  /// la foto del modo anterior se desvanece encima: un fundido limpio, sin parpadeos.
  void _alCambiarModo() {
    setState(() {});
    void redibujar(Element elemento) {
      elemento.markNeedsBuild();
      elemento.visitChildren(redibujar);
    }

    (context as Element).visitChildren(redibujar);
    if (_foto != null) {
      _fundido.reverse(from: 1).whenComplete(() {
        if (!mounted) return;
        _foto?.dispose();
        setState(() => _foto = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _pantalla,
            child: MaterialApp(
              title: 'PrevenApp',
              debugShowCheckedModeBanner: false,
              theme: temaPrevenApp(),
              // Sin animación propia del tema: la transición la hace el fundido
              themeAnimationDuration: Duration.zero,
              // Toda la app en español: calendario, selector de fechas, botones...
              locale: const Locale('es', 'ES'),
              supportedLocales: const [Locale('es', 'ES')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const ArranquePantalla(),
            ),
          ),
          if (foto != null)
            IgnorePointer(
              child: FadeTransition(
                opacity: _fundido,
                child: RawImage(image: foto, fit: BoxFit.fill),
              ),
            ),
        ],
      ),
    );
  }
}

/// Primera pantalla: comprueba si ya había una sesión guardada.
/// Si la hay, entra directamente; si no, muestra el inicio de sesión.
class ArranquePantalla extends StatefulWidget {
  const ArranquePantalla({super.key});

  @override
  State<ArranquePantalla> createState() => _ArranquePantallaState();
}

class _ArranquePantallaState extends State<ArranquePantalla> {
  @override
  void initState() {
    super.initState();
    _comprobarSesion();
  }

  Future<void> _comprobarSesion() async {
    await api.cargarSesion();
    Widget destino = const LoginPantalla();
    if (api.haySesion) {
      try {
        final usuario = await api.yo();
        destino = InicioPantalla(usuario: usuario);
      } on ApiError {
        // Token caducado o sin conexión: se pide iniciar sesión de nuevo
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
