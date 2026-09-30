import 'package:flutter/material.dart';

/// Muestra un diálogo dentro de la ventana y devuelve su resultado.
/// (Como `showDialog`, pero siempre dentro de la ventana de la app.)
Future<T?> mostrarDialogo<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(DialogRoute<T>(
      context: context,
      builder: builder,
    ));

/// Pregunta con "Cancelar" y [textoSi]. Devuelve true si se acepta.
Future<bool> preguntar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoSi,
}) async {
  final respuesta = await mostrarDialogo<bool>(
    context,
    (contexto) => AlertDialog(
      scrollable: true,
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(textoSi),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}

/// Muestra un mensaje de error que se puede seleccionar y copiar.
void mostrarError(BuildContext context, String mensaje) {
  mostrarDialogo<void>(
    context,
    (contexto) => AlertDialog(
      title: const Text('Error'),
      content: SingleChildScrollView(child: SelectableText(mensaje)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Explica los errores habituales de SQLite; el resto, tal cual.
String explicarError(Object error) {
  final texto = error.toString();
  if (texto.contains('database is locked')) {
    return 'El archivo está bloqueado por otro programa (por ejemplo, '
        'DB Browser for SQLite). Ciérralo y vuelve a intentarlo.';
  }
  if (texto.contains('readonly') || texto.contains('read-only')) {
    return 'El archivo es de solo lectura. Quita el atributo "Solo lectura" '
        'en sus propiedades de Windows.';
  }
  if (texto.contains('not a database') || texto.contains('file is encrypted')) {
    return 'El archivo no es una base de datos SQLite válida.';
  }
  return texto;
}
