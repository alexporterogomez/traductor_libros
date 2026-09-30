// Pruebas automáticas del proyecto. Se ejecutan con `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traductor_libros/modelos/palabra.dart';
import 'package:traductor_libros/modelos/parrafo.dart';
import 'package:traductor_libros/servicios/servicio_ia.dart';
import 'package:traductor_libros/utilidades/reemplazo.dart';
import 'package:traductor_libros/widgets/tabla_palabras.dart';
import 'package:traductor_libros/widgets/tabla_parrafos.dart';

/// Crea un párrafo de prueba.
Parrafo _parrafo(int id, String texto) => Parrafo.desdeFila({
      'id': id,
      'parrafo': id,
      'bloque': 0,
      'caracteres': 0,
      'original': texto,
    });

/// Prepara una ventana de 1000 x 700 y muestra [contenido] en ella.
Future<void> _mostrar(WidgetTester tester, Widget contenido) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: contenido)));
  await tester.pumpAndSettle();
}

/// Muestra la tabla de párrafos con [parrafos].
Future<void> _mostrarTabla(WidgetTester tester, List<Parrafo> parrafos) =>
    _mostrar(
      tester,
      TablaParrafos(
        parrafos: parrafos,
        idSeleccionado: null,
        onSeleccionar: (_) async => true,
      ),
    );

/// Muestra la tabla de palabras con el estado de guardado indicado.
Future<void> _mostrarPalabras(WidgetTester tester,
        {required bool hayCambios, required int versiones}) =>
    _mostrar(
      tester,
      TablaPalabras(
        revision: 0,
        palabras: Palabra.desdeKeys('{"0":"The|the|det"}'),
        hayCambios: hayCambios,
        versionesAnteriores: versiones,
        mensajeVacio: '',
        onEditar: (_) {},
        onGuardar: () {},
        onRevertir: () {},
        generando: false,
        onGenerar: () {},
      ),
    );

/// Indica si el botón con el texto [texto] está habilitado.
bool _habilitado(WidgetTester tester, String texto) {
  final boton = find.ancestor(
    of: find.text(texto),
    matching: find.bySubtype<ButtonStyleButton>(),
  );
  return tester.widget<ButtonStyleButton>(boton).onPressed != null;
}

void main() {
  test('Parrafo lee una fila de la base de datos', () {
    final parrafo = Parrafo.desdeFila({
      'id': 6,
      'parrafo': 5,
      'bloque': 1,
      'caracteres': 284,
      'original': 'No artist has ethical sympathies.',
    });
    expect(parrafo.id, 6);
    expect(parrafo.parrafo, 5);
    expect(parrafo.bloque, 1);
    expect(parrafo.caracteres, 284);
  });

  test('Si "caracteres" viene a 0 se calcula con el texto', () {
    expect(_parrafo(1, 'How the Hedgehog Found Happiness').caracteres, 32);
  });

  test('Palabras de la columna keys ordenadas por posición', () {
    final palabras = Palabra.desdeKeys(
        '{"0":"The|the|det","10":"moral|moral|adj","2":"is|be|verb"}');
    expect(palabras.map((p) => p.indice), [0, 2, 10]);
    expect(palabras[1].palabra, 'is');
    expect(palabras[1].lema, 'be');
    expect(palabras[1].tipo, 'verb');
    expect(Palabra.desdeKeys(null), isEmpty);
    expect(Palabra.desdeKeys('no es json'), isEmpty);
  });

  test('Las palabras editadas se convierten de nuevo al formato keys', () {
    final palabras = Palabra.desdeKeys('{"0":"The|the|det","1":"is|be|verb"}');
    final editadas = [palabras[0], palabras[1].copyWith(lema: 'ser')];
    expect(Palabra.aKeys(editadas), '{"0":"The|the|det","1":"is|ser|verb"}');
  });

  test('La corrección busca palabras completas sin distinguir mayúsculas', () {
    final reemplazo = Reemplazo(buscar: 'to-day', reemplazo: 'today');
    const texto = 'To-day, not to-days: TO-DAY and to-day.';
    expect(reemplazo.contar(texto), 3);
    expect(reemplazo.aplicar(texto), 'today, not to-days: today and today.');

    final tramos = reemplazo.tramos('I came to-day.', sustituir: true);
    expect(tramos, [('I came ', false), ('today', true), ('.', false)]);
  });

  test('La corrección puede buscar dentro de otras palabras', () {
    final reemplazo =
        Reemplazo(buscar: 'shew', reemplazo: 'show', palabraCompleta: false);
    expect(reemplazo.aplicar('He shewn and shews'), 'He shown and shows');
  });

  test('conOriginal cambia solo el texto original', () {
    final parrafo = _parrafo(1, 'The Picture of Dorian Gray');
    final nuevo = parrafo.conOriginal('Otro texto');
    expect(nuevo.original, 'Otro texto');
    expect(nuevo.id, parrafo.id);
  });

  test('La respuesta de la IA se limpia', () {
    expect(
      ServicioIA.limpiarRespuesta('<think>pensando</think>\nHola mundo.'),
      'Hola mundo.',
    );
    expect(ServicioIA.limpiarRespuesta('```text\nHola mundo.\n```'),
        'Hola mundo.');
  });

  testWidgets('La tabla muestra los títulos completos', (tester) async {
    await _mostrarTabla(tester, [
      _parrafo(1, 'How the Hedgehog Found Happiness'),
      _parrafo(2, 'Pip was a small hedgehog.'),
    ]);
    for (final titulo in ['ID', 'Párrafo', 'Bloque', 'Texto', 'Fecha']) {
      expect(find.text(titulo), findsOneWidget);
    }
  });

  testWidgets('Guardar y Revertir de las palabras según su estado',
      (tester) async {
    // Sin cambios ni historial: los dos botones deshabilitados.
    await _mostrarPalabras(tester, hayCambios: false, versiones: 0);
    expect(_habilitado(tester, 'Guardar'), isFalse);
    expect(_habilitado(tester, 'Revertir'), isFalse);

    // Con historial: se puede revertir a la versión anterior.
    await _mostrarPalabras(tester, hayCambios: false, versiones: 2);
    expect(_habilitado(tester, 'Guardar'), isFalse);
    expect(_habilitado(tester, 'Revertir'), isTrue);
    expect(find.text('2 versiones anteriores'), findsOneWidget);

    // Con cambios sin guardar: se puede guardar o descartar.
    await _mostrarPalabras(tester, hayCambios: true, versiones: 0);
    expect(_habilitado(tester, 'Guardar'), isTrue);
    expect(_habilitado(tester, 'Revertir'), isTrue);
    expect(find.text('Cambios sin guardar'), findsOneWidget);
  });
}
