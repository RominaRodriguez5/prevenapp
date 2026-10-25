/// Pequeñas funciones para mostrar fechas e importes en formato español.
library;

/// 2026-10-05 → "05/10/2026"
String fechaTexto(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// DateTime → "2026-10-05", el formato que entiende la API.
String fechaApi(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$mes-$dia';
}

/// 1250.5 → "1250,50 €"
String euros(double importe) => '${importe.toStringAsFixed(2).replaceAll('.', ',')} €';

/// "1.250,50" o "1250.50" → 1250.5. Devuelve null si no es un número válido.
double? leerImporte(String texto) {
  var limpio = texto.trim().replaceAll('€', '').replaceAll(' ', '');
  if (limpio.contains(',')) {
    // Formato español: los puntos son miles y la coma es el decimal
    limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(limpio);
}

const meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

const mesesCortos = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

const diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

/// 2026-10-24 → "Sábado 24 de octubre"
String fechaLarga(DateTime fecha) =>
    '${diasSemana[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1].toLowerCase()}';

/// 12.0 → "12"; 12.5 → "12,5"; 12.25 → "12,25"
String numero(double valor) {
  var texto = valor.toStringAsFixed(2);
  texto = texto.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return texto.replaceAll('.', ',');
}
