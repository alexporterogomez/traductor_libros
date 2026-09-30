/// Párrafo del libro con los datos de la tabla de párrafos.
///
/// Solo guarda el texto original; las traducciones se leen al seleccionarlo.
class Parrafo {
  Parrafo({
    required this.id,
    required this.parrafo,
    required this.bloque,
    required this.caracteres,
    required this.fecha,
    required this.original,
    this.idCuento,
  });

  /// Identificador único de la fila (columna `id`).
  final int id;

  /// Cuento al que pertenece (columna `id_cuento`), o null si el libro no
  /// es de cuentos.
  final int? idCuento;

  /// Número de párrafo (columna `parrafo`), o null.
  final int? parrafo;

  /// Parte del párrafo (columna `bloque`), o null.
  final int? bloque;

  /// Número de caracteres del texto original.
  final int caracteres;

  /// Fecha (columna `fecha`) tal cual, o null.
  final String? fecha;

  /// Texto completo en el idioma original.
  final String original;

  /// Copia del párrafo con otro texto original (tras una corrección).
  Parrafo conOriginal(String texto) => Parrafo(
        id: id,
        parrafo: parrafo,
        bloque: bloque,
        caracteres: texto.runes.length,
        fecha: fecha,
        original: texto,
        idCuento: idCuento,
      );

  /// Copia del párrafo con otra fecha (tras guardar o revertir).
  Parrafo conFecha(String? nueva) => Parrafo(
        id: id,
        parrafo: parrafo,
        bloque: bloque,
        caracteres: caracteres,
        fecha: nueva,
        original: original,
        idCuento: idCuento,
      );

  /// Crea un párrafo a partir de una fila de SQLite. Si `caracteres` falta
  /// o vale 0, se calcula con el texto.
  factory Parrafo.desdeFila(Map<String, Object?> fila) {
    final original = (fila['original'] ?? '').toString();
    final caracteres = aEntero(fila['caracteres']);
    final fecha = fila['fecha']?.toString().trim() ?? '';
    return Parrafo(
      id: aEntero(fila['id']) ?? 0,
      parrafo: aEntero(fila['parrafo']),
      bloque: aEntero(fila['bloque']),
      caracteres: (caracteres == null || caracteres <= 0)
          ? original.runes.length
          : caracteres,
      fecha: fecha.isEmpty ? null : fecha,
      original: original,
      idCuento: aEntero(fila['id_cuento']),
    );
  }

  /// Convierte un valor de SQLite a entero, o null.
  static int? aEntero(Object? valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString().trim());
  }
}
