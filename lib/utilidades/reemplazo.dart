/// Busca y sustituye una palabra en un texto (función Corregir).
///
/// La búsqueda no distingue mayúsculas; el reemplazo se escribe tal cual.
class Reemplazo {
  Reemplazo({
    required String buscar,
    required this.reemplazo,
    this.palabraCompleta = true,
  }) : _patron = buscar.isEmpty
            ? null
            : RegExp(
                palabraCompleta
                    // Sin letras ni números alrededor: palabra completa.
                    ? '(?<![\\p{L}\\p{N}_])${RegExp.escape(buscar)}'
                        '(?![\\p{L}\\p{N}_])'
                    : RegExp.escape(buscar),
                caseSensitive: false,
                unicode: true,
              );

  /// Texto que sustituye a cada aparición.
  final String reemplazo;

  /// Solo palabras completas ("shew" no está dentro de "shewn").
  final bool palabraCompleta;

  /// Expresión regular de búsqueda, o null si no hay nada que buscar.
  final RegExp? _patron;

  /// Número de veces que aparece la palabra en [texto].
  int contar(String texto) => _patron?.allMatches(texto).length ?? 0;

  /// Texto con todas las apariciones sustituidas.
  String aplicar(String texto) {
    final patron = _patron;
    if (patron == null) return texto;
    return texto.replaceAll(patron, reemplazo);
  }

  /// Divide [texto] en tramos (texto, ¿es la palabra?) para resaltarla.
  /// Con [sustituir], la palabra aparece ya corregida.
  List<(String, bool)> tramos(String texto, {required bool sustituir}) {
    final patron = _patron;
    if (patron == null) return [(texto, false)];

    final tramos = <(String, bool)>[];
    var inicio = 0;
    for (final m in patron.allMatches(texto)) {
      if (m.start > inicio) {
        tramos.add((texto.substring(inicio, m.start), false));
      }
      tramos.add((sustituir ? reemplazo : m[0]!, true));
      inicio = m.end;
    }
    if (inicio < texto.length) tramos.add((texto.substring(inicio), false));
    return tramos;
  }
}
