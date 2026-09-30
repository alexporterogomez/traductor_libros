import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utilidades/idiomas.dart';

/// Una tarjeta por idioma (el original primero). Siempre caben todas; el
/// número de columnas depende del espacio. Al pulsar una, se edita ese
/// idioma.
class TarjetasIdiomas extends StatelessWidget {
  const TarjetasIdiomas({
    super.key,
    required this.idiomas,
    required this.idiomaOriginal,
    required this.idiomaSeleccionado,
    required this.textos,
    required this.cambiosSinGuardar,
    required this.onSeleccionar,
  });

  /// Códigos de todos los idiomas del libro.
  final List<String> idiomas;

  /// Código del idioma original (su tarjeta va primero).
  final String idiomaOriginal;

  /// Idioma que se está editando (tarjeta resaltada).
  final String? idiomaSeleccionado;

  /// Texto del párrafo en cada idioma.
  final Map<String, String> textos;

  /// Si es true, la tarjeta seleccionada muestra un indicador naranja.
  final bool cambiosSinGuardar;

  /// Se llama al pulsar una tarjeta, con el código de su idioma.
  final ValueChanged<String> onSeleccionar;

  /// Separación entre tarjetas, en píxeles.
  static const double _separacion = 8;

  /// Proporción ancho / alto deseada para las tarjetas (apaisadas).
  static const double _proporcion = 2.5;

  @override
  Widget build(BuildContext context) {
    final orden = [
      idiomaOriginal,
      ...idiomas.where((idioma) => idioma != idiomaOriginal),
    ];

    return LayoutBuilder(
      builder: (context, restricciones) {
        final columnas = _elegirColumnas(
          orden.length,
          restricciones.maxWidth - 2 * _separacion,
          restricciones.maxHeight - 2 * _separacion,
        );
        final filas = (orden.length / columnas).ceil();

        // Rejilla que llena el espacio; los huecos de la última fila quedan
        // vacíos.
        return Padding(
          padding: const EdgeInsets.all(_separacion),
          child: Column(
            children: [
              for (var fila = 0; fila < filas; fila++) ...[
                if (fila > 0) const SizedBox(height: _separacion),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var columna = 0; columna < columnas; columna++) ...[
                        if (columna > 0) const SizedBox(width: _separacion),
                        Expanded(
                          child: fila * columnas + columna < orden.length
                              ? _tarjeta(context, orden[fila * columnas + columna])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Número de columnas con el que las tarjetas quedan más grandes.
  static int _elegirColumnas(int total, double ancho, double alto) {
    var mejor = 1;
    var mejorTamano = 0.0;
    for (var columnas = 1; columnas <= total; columnas++) {
      final filas = (total / columnas).ceil();
      final anchoTarjeta = (ancho - (columnas - 1) * _separacion) / columnas;
      final altoTarjeta = (alto - (filas - 1) * _separacion) / filas;
      // Tamaño del mayor rectángulo apaisado que cabe.
      final tamano = math.min(anchoTarjeta / _proporcion, altoTarjeta);
      if (tamano > mejorTamano) {
        mejorTamano = tamano;
        mejor = columnas;
      }
    }
    return mejor;
  }

  /// Tarjeta de un idioma: nombre, columna y texto.
  Widget _tarjeta(BuildContext context, String idioma) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final esOriginal = idioma == idiomaOriginal;
    final seleccionada = idioma == idiomaSeleccionado;
    final texto = (textos[idioma] ?? '').trim();
    final titulo = esOriginal
        ? '${nombreIdioma(idioma)} · original (texto_$idioma)'
        : '${nombreIdioma(idioma)} (texto_$idioma)';

    return Card(
      margin: EdgeInsets.zero,
      elevation: seleccionada ? 2 : 0,
      clipBehavior: Clip.antiAlias,
      // El original siempre en verde; la seleccionada, con borde grueso.
      color: esOriginal
          ? Colors.green.shade100
          : (seleccionada ? colores.primaryContainer : colores.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: seleccionada
              ? colores.primary
              : (esOriginal ? Colors.green.shade400 : colores.outlineVariant),
          width: seleccionada ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onSeleccionar(idioma),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (seleccionada && cambiosSinGuardar)
                    Icon(Icons.circle, size: 10, color: Colors.orange.shade700),
                ],
              ),
              const SizedBox(height: 4),
              // Texto completo; si no cabe, se desplaza dentro de la tarjeta.
              Expanded(
                child: SingleChildScrollView(
                  // Clave nueva por párrafo: el desplazamiento vuelve arriba.
                  key: ObjectKey(textos),
                  child: Text(
                    textos.isEmpty
                        ? ''
                        : (texto.isEmpty ? 'Sin traducir' : texto),
                    style: tema.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      fontStyle: texto.isEmpty ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
