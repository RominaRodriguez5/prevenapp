import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movil/config.dart';
import 'package:movil/pantallas/login.dart';
import 'package:movil/tema.dart';
import 'package:movil/utilidades/formato.dart';
import 'package:movil/utilidades/turnos.dart';

void main() {
  testWidgets('La pantalla de inicio de sesión muestra los campos y el botón', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: temaPrevenApp(), home: const LoginPantalla()));

    expect(find.text('PrevenApp'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Escribe solo tu usuario, sin @previs.es'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Si se pulsa Entrar sin datos, pide rellenarlos', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: temaPrevenApp(), home: const LoginPantalla()));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe tu usuario'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  test('Si se escribe solo el usuario, se añade el dominio de la empresa', () {
    expect(emailCompleto('ana'), 'ana@previs.es');
    expect(emailCompleto(' Ana '), 'ana@previs.es');
    expect(emailCompleto('ana@demo.es'), 'ana@demo.es');
  });

  test('Formato de fechas e importes en español', () {
    expect(fechaTexto(DateTime(2026, 3, 5)), '05/03/2026');
    expect(fechaApi(DateTime(2026, 3, 5)), '2026-03-05');
    expect(euros(1250.5), '1250,50 €');
    expect(leerImporte('1.250,50'), 1250.5);
    expect(leerImporte('1250.50'), 1250.5);
    expect(leerImporte('1250'), 1250);
    expect(leerImporte('hola'), isNull);
    expect(fechaLarga(DateTime(2026, 10, 24)), 'Sábado 24 de octubre');
    expect(numero(12), '12');
    expect(numero(12.5), '12,5');
    expect(numero(54.25), '54,25');
  });

  test('Turno propuesto: extra en fin de semana', () {
    expect(turnoPara(DateTime(2026, 10, 22)), 'manana'); // jueves
    expect(turnoPara(DateTime(2026, 10, 22), tarde: true), 'tarde');
    expect(turnoPara(DateTime(2026, 10, 24)), 'extra_manana'); // sábado
    expect(turnoPara(DateTime(2026, 10, 25), tarde: true), 'extra_tarde'); // domingo
  });
}
