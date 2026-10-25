/// Turnos de la formación.
///
/// Los "extra" son los que se hacen fuera de lunes a viernes. La app propone el turno
/// según el día, pero el técnico siempre puede cambiarlo (por ejemplo, un festivo).
library;

const turnos = ['manana', 'tarde', 'extra_manana', 'extra_tarde'];

const nombresTurno = {
  'manana': 'Mañana',
  'tarde': 'Tarde',
  'extra_manana': 'Extra mañana',
  'extra_tarde': 'Extra tarde',
};

bool esFinDeSemana(DateTime fecha) => fecha.weekday >= DateTime.saturday;

bool esDeTarde(String turno) => turno.endsWith('tarde');

/// Turno propuesto para un día, manteniendo si era de mañana o de tarde.
/// Sábado y domingo → extra; de lunes a viernes → normal.
String turnoPara(DateTime fecha, {bool tarde = false}) {
  if (esFinDeSemana(fecha)) return tarde ? 'extra_tarde' : 'extra_manana';
  return tarde ? 'tarde' : 'manana';
}
