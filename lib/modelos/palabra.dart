import 'dart:convert';

/// Palabra del texto original con su lema y tipo.
///
/// Sale de la columna `keys`: `{"0": "The|the|det", ...}`.
class Palabra {
  const Palabra(this.indice, this.palabra, this.lema, this.tipo);

  /// Posición de la palabra dentro del párrafo.
  final int indice;

  /// Palabra tal como aparece en el texto.
  final String palabra;

  /// Forma base de la palabra (por ejemplo, "be" para "is").
  final String lema;

  /// Etiqueta gramatical en formato Universal POS (`noun`, `verb`, `adj`...).
  final String tipo;

  /// Copia de la palabra con los campos indicados cambiados.
  Palabra copyWith({String? palabra, String? lema, String? tipo}) => Palabra(
        indice,
        palabra ?? this.palabra,
        lema ?? this.lema,
        tipo ?? this.tipo,
      );

  /// Convierte el JSON de `keys` en una lista ordenada por posición.
  /// Devuelve una lista vacía si no hay datos o el JSON no es válido.
  static List<Palabra> desdeKeys(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      final datos = jsonDecode(json);
      if (datos is! Map) return [];
      final palabras = [
        for (final entrada in datos.entries)
          _desdeTexto(entrada.key.toString(), entrada.value.toString()),
      ];
      return palabras..sort((a, b) => a.indice.compareTo(b.indice));
    } on FormatException {
      return [];
    }
  }

  /// Convierte la lista al formato de `keys` (JSON compacto).
  static String aKeys(List<Palabra> palabras) => jsonEncode({
        for (final p in palabras) '${p.indice}': '${p.palabra}|${p.lema}|${p.tipo}',
      });

  /// Crea una palabra a partir de `"palabra|lema|tipo"`.
  static Palabra _desdeTexto(String clave, String valor) {
    final partes = valor.split('|');
    String parte(int i) => i < partes.length ? partes[i] : '';
    return Palabra(int.tryParse(clave) ?? 0, parte(0), parte(1), parte(2));
  }
}
