import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_visualizer/json_visualizer.dart';

import '../modelos/palabra.dart';

/// Panel con dos pestañas en JSON (json_visualizer): capítulos del libro
/// y palabras del párrafo seleccionado.
class PanelJson extends StatefulWidget {
  const PanelJson({
    super.key,
    required this.capitulos,
    required this.palabras,
  });

  /// JSON de capítulos, o null si el libro no lo tiene.
  final String? capitulos;

  /// Palabras del párrafo seleccionado.
  final List<Palabra> palabras;

  @override
  State<PanelJson> createState() => _PanelJsonState();
}

/// Pestañas del panel.
enum _Pestana { capitulos, palabras }

class _PanelJsonState extends State<PanelJson> {
  _Pestana _pestana = _Pestana.palabras;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colores.surface,
        border: Border.all(color: colores.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: SegmentedButton<_Pestana>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Pestana.palabras,
                  label: Text('Palabras'),
                ),
                ButtonSegment(
                  value: _Pestana.capitulos,
                  label: Text('Capítulos'),
                ),
              ],
              selected: {_pestana},
              onSelectionChanged: (seleccion) =>
                  setState(() => _pestana = seleccion.first),
            ),
          ),
          Divider(height: 1, color: colores.outlineVariant),
          Expanded(
            child: _pestana == _Pestana.capitulos
                ? _capitulos()
                : _palabras(),
          ),
        ],
      ),
    );
  }

  /// Contenido de la pestaña Capítulos.
  Widget _capitulos() {
    final texto = widget.capitulos;
    if (texto == null) {
      return const Center(child: Text('Este libro no tiene capítulos'));
    }
    try {
      return _arbol(jsonDecode(texto));
    } on FormatException {
      // No es un JSON válido: se muestra el texto tal cual.
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [SelectableText(texto)],
      );
    }
  }

  /// Pestaña Palabras: un objeto por palabra.
  Widget _palabras() {
    if (widget.palabras.isEmpty) {
      return const Center(child: Text('No hay palabras'));
    }
    return _arbol({
      for (final p in widget.palabras)
        '${p.indice}': {'palabra': p.palabra, 'lema': p.lema, 'tipo': p.tipo},
    });
  }

  /// Árbol desplegable del JSON [datos].
  Widget _arbol(Object? datos) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [JsonVisualizer(data: datos, fontSize: 13, expandDepth: 2)],
    );
  }
}
