import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo oscuro activado o no. Al cambiarlo, la app entera se vuelve a dibujar
/// con los colores del modo elegido (ver main.dart).
final modoOscuro = ValueNotifier<bool>(false);

/// Nombre con el que se guarda en el móvil la elección de modo claro u oscuro.
const claveModoOscuro = 'modo_oscuro';

/// Se llama justo antes de cambiar de modo (la usa main.dart para hacer la "foto"
/// de la pantalla y la transición suave).
Future<void> Function()? antesDeCambiarModo;

/// Cambia entre modo claro y oscuro y lo recuerda para la próxima vez.
Future<void> cambiarModoOscuro() async {
  await antesDeCambiarModo?.call();
  modoOscuro.value = !modoOscuro.value;
  final preferencias = await SharedPreferences.getInstance();
  await preferencias.setBool(claveModoOscuro, modoOscuro.value);
}

/// Colores de PrevenApp (basados en el diseño de Figma), en modo claro y oscuro.
///
/// - Fondo gris muy claro (o casi negro) y tarjetas blancas (o gris oscuro).
/// - Morado como color principal y lavanda para botones y elementos seleccionados.
/// - Verde suave para los resúmenes ("todo va bien") y rojo suave para lo atrasado.
///
/// Son "getters": cada vez que se piden devuelven el color del modo actual.
class Paleta {
  static bool get _oscuro => modoOscuro.value;
  static Color _c(int claro, int oscuro) => Color(_oscuro ? oscuro : claro);

  // Base
  static Color get fondo => _c(0xFFF3F4F6, 0xFF121418);
  static Color get borde => _c(0xFFE5E7EB, 0xFF2C303A);
  static Color get blanco => _c(0xFFFFFFFF, 0xFF1C1F27); // superficie de las tarjetas
  static Color get tinta => _c(0xFF1E2330, 0xFFECEDF2); // texto principal
  static Color get tintaSuave => _c(0xFF6B7280, 0xFF9CA3AF);

  // Principal
  static Color get morado => _c(0xFF5E4B8B, 0xFFBBA8F2);
  static Color get lavanda => _c(0xFFE2D9F5, 0xFF3A3358);
  static Color get lavandaSuave => _c(0xFFF1ECFA, 0xFF27223D);

  // Estados
  static Color get verdeSuave => _c(0xFFE3EFDC, 0xFF1E3326);
  static Color get verde => _c(0xFF3C7A4E, 0xFF7CC594);
  static Color get rojo => _c(0xFFC0392B, 0xFFFF8A80);
  static Color get rojoSuave => _c(0xFFFDECEA, 0xFF3A2022);
  static Color get rojoBorde => _c(0xFFF3B9B1, 0xFF6E2F2C);

  // Nombres antiguos, para que el resto del código siga funcionando
  static Color get papel => fondo;
  static Color get papelOscuro => borde;
  static Color get naranja => morado;
  static Color get baliza => lavanda;
  static Color get sello => verde;
}

/// Texto pequeño en mayúsculas que va encima de los títulos ("MI ACTIVIDAD · RESUMEN MENSUAL").
TextStyle get estiloSobretitulo => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Paleta.morado,
    );

/// Título de sección ("Cómo se calcula", "Tu próxima visita").
TextStyle get estiloSeccion => TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Paleta.tinta);

/// Cifras grandes de los resúmenes ("228,00 €", "428 km"): grandes y finas.
TextStyle get estiloCifra => TextStyle(fontSize: 44, fontWeight: FontWeight.w400, color: Paleta.tinta, height: 1.1);

ThemeData temaPrevenApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Paleta.morado,
    brightness: modoOscuro.value ? Brightness.dark : Brightness.light,
    primary: Paleta.morado,
    onPrimary: Paleta.blanco,
    secondary: Paleta.morado,
    surface: Paleta.blanco,
    onSurface: Paleta.tinta,
    error: Paleta.rojo,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Paleta.borde, width: 1.2),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Paleta.fondo,
    visualDensity: VisualDensity.comfortable,
    textTheme: base.textTheme.apply(bodyColor: Paleta.tinta, displayColor: Paleta.tinta),
    appBarTheme: AppBarTheme(
      backgroundColor: Paleta.blanco,
      foregroundColor: Paleta.tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Paleta.tinta, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    ),
    cardTheme: CardThemeData(
      color: Paleta.blanco,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Paleta.borde),
      ),
    ),
    // Botón principal: lavanda con borde morado y texto oscuro
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.lavanda,
        foregroundColor: Paleta.tinta,
        disabledBackgroundColor: Paleta.lavandaSuave,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Paleta.morado, width: 1.2),
        ),
      ),
    ),
    // Botón secundario: blanco con texto morado
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Paleta.blanco,
        foregroundColor: Paleta.morado,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Paleta.borde, width: 1.2),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Paleta.morado,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Paleta.lavanda,
      foregroundColor: Paleta.tinta,
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: Paleta.morado, width: 1.2)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.blanco,
      labelStyle: TextStyle(color: Paleta.tintaSuave),
      floatingLabelStyle: TextStyle(color: Paleta.morado, fontWeight: FontWeight.w700),
      prefixIconColor: Paleta.tintaSuave,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(borderSide: BorderSide(color: Paleta.morado, width: 1.8)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Paleta.blanco,
      selectedColor: Paleta.lavanda,
      side: BorderSide(color: Paleta.borde),
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: Paleta.tinta),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? Paleta.lavanda : Paleta.blanco,
        ),
        foregroundColor: WidgetStateProperty.all(Paleta.tinta),
        side: WidgetStateProperty.all(BorderSide(color: Paleta.borde)),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? Colors.white : Paleta.tintaSuave,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? Paleta.morado : Paleta.borde,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Paleta.morado, linearTrackColor: Paleta.borde),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.blanco,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Paleta.lavanda,
      iconTheme: WidgetStateProperty.all(IconThemeData(color: Paleta.tinta)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontSize: 13,
          color: estados.contains(WidgetState.selected) ? Paleta.morado : Paleta.tinta,
          fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Paleta.verdeSuave,
      contentTextStyle: TextStyle(color: Paleta.tinta, fontSize: 15, fontWeight: FontWeight.w600),
      actionTextColor: Paleta.tinta,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: Paleta.borde, space: 1),
  );
}

/// Título de pantalla al estilo del diseño: sobretítulo pequeño en morado y título grande.
class Cabecera extends StatelessWidget {
  final String sobretitulo;
  final String titulo;

  const Cabecera({super.key, required this.sobretitulo, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(sobretitulo.toUpperCase(), style: estiloSobretitulo, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(titulo, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Tarjeta de resumen (verde por defecto), como "Acumulado este mes".
class TarjetaResumen extends StatelessWidget {
  final Widget child;
  final Color? _color;

  const TarjetaResumen({super.key, required this.child, Color? color}) : _color = color;

  Color get color => _color ?? Paleta.verdeSuave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: child,
    );
  }
}

/// Barra de progreso redondeada (morada sobre gris).
class BarraProgreso extends StatelessWidget {
  final double valor; // de 0 a 1

  const BarraProgreso({super.key, required this.valor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: Paleta.borde,
        color: Paleta.morado,
      ),
    );
  }
}

/// Etiqueta pequeña tipo pastilla ("⚠ Actividad atrasada", "Confirmada").
class Pastilla extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Color? _fondo;
  final Color? _letra;
  final bool _atrasada;

  const Pastilla({super.key, required this.texto, this.icono, Color? fondo, Color? letra})
      : _fondo = fondo,
        _letra = letra,
        _atrasada = false;

  /// Pastilla roja para lo atrasado.
  const Pastilla.atrasada({super.key, required this.texto, this.icono = Icons.warning_amber_rounded})
      : _fondo = null,
        _letra = null,
        _atrasada = true;

  Color get fondo => _fondo ?? (_atrasada ? Paleta.rojoSuave : Paleta.lavandaSuave);
  Color get letra => _letra ?? (_atrasada ? Paleta.rojo : Paleta.morado);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: letra),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: letra, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
