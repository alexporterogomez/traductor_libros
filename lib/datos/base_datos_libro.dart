import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../modelos/palabra.dart';
import '../modelos/parrafo.dart';
import 'datos_programa.dart';
import 'repositorio_libro.dart';

/// Libro guardado en un archivo SQLite (`.db`).
///
/// La estructura se detecta al abrirlo: tabla `libro`, un idioma por cada
/// columna `texto_xx` con texto e idioma original según `idioma_original`.
/// El historial para revertir se guarda aparte, en [DatosPrograma].
class BaseDatosLibro extends RepositorioLibro {
  BaseDatosLibro._({
    required this._db,
    required this._datos,
    required this.ruta,
    required this.tabla,
    required this.columnas,
    required this.idiomas,
    required this.idiomaOriginal,
  });

  final Database _db;
  final DatosPrograma _datos;

  /// Ruta completa del archivo `.db`.
  final String ruta;

  /// Nombre de la tabla que contiene los párrafos.
  final String tabla;

  /// Nombres de las columnas de [tabla], en minúsculas.
  final Set<String> columnas;

  @override
  final List<String> idiomas;

  @override
  final String idiomaOriginal;

  @override
  bool get esCuentos => columnas.contains('id_cuento');

  @override
  String get nombre => p.basenameWithoutExtension(ruta);

  /// Clave del libro en el historial: la ruta completa de su archivo.
  String get archivo => p.canonicalize(ruta);

  /// Abre el libro de [ruta]. Lanza un error si no existe o no tiene el
  /// formato esperado.
  static Future<BaseDatosLibro> abrir(String ruta, DatosPrograma datos) async {
    // Si el archivo no existe, SQLite crearía uno vacío en su lugar.
    if (!File(ruta).existsSync()) {
      throw FileSystemException('El archivo no existe', ruta);
    }

    final db = await databaseFactoryFfi.openDatabase(ruta);
    try {
      final tabla = await _buscarTabla(db);
      final info = await db.rawQuery('PRAGMA table_info(${_q(tabla)})');
      final columnas =
          info.map((c) => c['name'].toString().toLowerCase()).toSet();

      if (!columnas.contains('id')) {
        throw FormatException('La tabla "$tabla" no tiene la columna "id".');
      }

      // Códigos de idioma a partir de los nombres de columna: texto_es → es.
      final columnasTexto = columnas
          .where((c) => c.startsWith('texto_') && c.length > 'texto_'.length)
          .map((c) => c.substring('texto_'.length))
          .toList()
        ..sort();
      final idiomas = await _idiomasConTexto(db, tabla, columnasTexto);
      if (idiomas.isEmpty) {
        throw FormatException('La tabla "$tabla" no tiene textos '
            '(columnas texto_en, texto_es... vacías o inexistentes).');
      }

      return BaseDatosLibro._(
        db: db,
        datos: datos,
        ruta: ruta,
        tabla: tabla,
        columnas: columnas,
        idiomas: idiomas,
        idiomaOriginal:
            await _detectarIdiomaOriginal(db, tabla, columnas, idiomas),
      );
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  @override
  Future<void> cerrar() => _db.close();

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  @override
  Future<List<Parrafo>> cargarParrafos() async {
    // Las columnas que falten se leen como NULL.
    String columna(String nombre) =>
        columnas.contains(nombre) ? _q(nombre) : 'NULL';

    final filas = await _db.rawQuery(
      'SELECT "id" AS id, '
      '${columna('parrafo')} AS parrafo, '
      '${columna('bloque')} AS bloque, '
      '${columna('caracteres')} AS caracteres, '
      '${columna('fecha')} AS fecha, '
      '${columna('id_cuento')} AS id_cuento, '
      '${_q('texto_$idiomaOriginal')} AS original '
      'FROM ${_q(tabla)} ORDER BY "id"',
    );
    return filas.map(Parrafo.desdeFila).toList();
  }

  @override
  Future<Map<String, String>> leerTextos(int id) async {
    // Una consulta con todos los idiomas: SELECT "texto_es" AS "es", ...
    final seleccion =
        idiomas.map((i) => '${_q('texto_$i')} AS ${_q(i)}').join(', ');
    final filas = await _db.rawQuery(
      'SELECT $seleccion FROM ${_q(tabla)} WHERE "id" = ?',
      [id],
    );
    if (filas.isEmpty) return {};
    return {for (final i in idiomas) i: (filas.first[i] ?? '').toString()};
  }

  @override
  Future<String?> leerFecha(int id) async {
    if (!columnas.contains('fecha')) return null;
    final filas = await _db.rawQuery(
      'SELECT "fecha" AS fecha FROM ${_q(tabla)} WHERE "id" = ?',
      [id],
    );
    final fecha = filas.isEmpty ? '' : '${filas.first['fecha'] ?? ''}'.trim();
    return fecha.isEmpty ? null : fecha;
  }

  @override
  Future<String?> leerCapitulos() async {
    if (esCuentos && columnas.contains('titulo')) return _titulosCuentos();
    if (!columnas.contains('capitulos')) return null;
    // Se toma la primera fila con capítulos.
    final filas = await _db.rawQuery(
      'SELECT "capitulos" AS c FROM ${_q(tabla)} '
      "WHERE TRIM(COALESCE(\"capitulos\", '')) <> '' "
      'ORDER BY "id" LIMIT 1',
    );
    return filas.isEmpty ? null : filas.first['c']?.toString();
  }

  /// Libros de cuentos: JSON con el título de cada cuento, que está en la
  /// columna `titulo` de su primer párrafo.
  Future<String?> _titulosCuentos() async {
    final filas = await _db.rawQuery(
      'SELECT "id" AS id, "id_cuento" AS id_cuento, "titulo" AS titulo '
      'FROM ${_q(tabla)} '
      "WHERE TRIM(COALESCE(\"titulo\", '')) <> '' "
      'ORDER BY "id"',
    );
    if (filas.isEmpty) return null;
    return jsonEncode([
      for (final fila in filas)
        {
          'id_cuento': fila['id_cuento'],
          'titulo': fila['titulo'].toString().trim(),
          'id': fila['id'], // Primer párrafo del cuento.
        },
    ]);
  }

  // ---------------------------------------------------------------------------
  // Texto original
  // ---------------------------------------------------------------------------

  @override
  Future<void> corregirOriginal(int id, String texto) => _guardarConHistorial(
      id, 'texto_$idiomaOriginal', idiomaOriginal, texto);

  @override
  Future<String?> revertirOriginal(int id) =>
      revertirTraduccion(id, idiomaOriginal);

  // ---------------------------------------------------------------------------
  // Traducciones
  // ---------------------------------------------------------------------------

  @override
  Future<void> guardarTraduccion(int id, String idioma, String texto) =>
      _guardarConHistorial(id, 'texto_$idioma', idioma, texto);

  @override
  Future<String?> revertirTraduccion(int id, String idioma) async {
    final version = await _revertir(id, 'texto_$idioma', idioma);
    return version == null ? null : (version.texto ?? '');
  }

  @override
  Future<int> contarVersionesTraduccion(int id, String idioma) =>
      _datos.contarVersiones(archivo, id, idioma);

  // ---------------------------------------------------------------------------
  // Palabras
  // ---------------------------------------------------------------------------

  @override
  Future<List<Palabra>> leerPalabras(int id) async {
    if (!columnas.contains('keys')) return [];
    final filas = await _db.rawQuery(
      'SELECT "keys" AS k FROM ${_q(tabla)} WHERE "id" = ?',
      [id],
    );
    return filas.isEmpty ? [] : Palabra.desdeKeys(filas.first['k']?.toString());
  }

  @override
  Future<void> guardarPalabras(int id, List<Palabra> palabras) async {
    if (!columnas.contains('keys')) {
      throw StateError('El libro no tiene la columna keys.');
    }
    await _guardarConHistorial(
        id, 'keys', DatosPrograma.campoPalabras, Palabra.aKeys(palabras));
  }

  @override
  Future<List<Palabra>?> revertirPalabras(int id) async {
    final version = await _revertir(id, 'keys', DatosPrograma.campoPalabras);
    return version == null ? null : Palabra.desdeKeys(version.texto);
  }

  @override
  Future<int> contarVersionesPalabras(int id) =>
      _datos.contarVersiones(archivo, id, DatosPrograma.campoPalabras);

  // ---------------------------------------------------------------------------
  // Escritura con historial
  // ---------------------------------------------------------------------------

  /// Escribe [valor] en [columna] y guarda el valor anterior en el
  /// historial. Si no cambia nada, no hace nada.
  Future<void> _guardarConHistorial(
      int id, String columna, String campo, String valor) async {
    final filas = await _db.rawQuery(
      'SELECT ${_q(columna)} AS valor FROM ${_q(tabla)} WHERE "id" = ?',
      [id],
    );
    if (filas.isEmpty) throw StateError('No existe el párrafo con id $id.');

    final anterior = filas.first['valor']?.toString();
    if (anterior == valor) return;

    // La fecha del párrafo antes y después del cambio se guarda en el
    // historial para poder volver a la anterior al revertir.
    final fechaAnterior = await leerFecha(id);
    final fechaNueva = columnas.contains('fecha') ? _fechaActual() : null;

    // Libro e historial están en archivos distintos: si falla la escritura,
    // se borra la entrada del historial para no dejarla incoherente.
    final idVersion = await _datos.anotarVersion(archivo, id, campo, anterior,
        fechaAnterior: fechaAnterior, fechaNueva: fechaNueva);
    try {
      await _escribir(id, columna, valor,
          cambiarFecha: fechaNueva != null, fecha: fechaNueva);
    } catch (_) {
      await _datos.borrarVersion(idVersion);
      rethrow;
    }
  }

  /// Restaura el último valor guardado en el historial y borra esa entrada.
  /// Devuelve la versión restaurada, o null si no había historial.
  Future<VersionAnterior?> _revertir(
      int id, String columna, String campo) async {
    final version = await _datos.ultimaVersion(archivo, id, campo);
    if (version == null) return null;

    // La fecha vuelve a la de antes del cambio, salvo que después se haya
    // cambiado otra cosa del párrafo (entonces se queda la de ese cambio).
    final fechaParrafo = await leerFecha(id);
    final volverFecha =
        version.fechaNueva != null && version.fechaNueva == fechaParrafo;
    await _escribir(id, columna, version.texto,
        cambiarFecha: volverFecha, fecha: version.fechaAnterior);
    await _datos.borrarVersion(version.id);
    return version;
  }

  /// Escribe [valor] en [columna] del párrafo [id]. Si [cambiarFecha], pone
  /// [fecha] en la columna `fecha`. Si cambia el original, actualiza también
  /// su número de caracteres (con espacios), si el libro tiene esa columna.
  /// Antes del primer cambio hace una copia.
  Future<void> _escribir(int id, String columna, String? valor,
      {bool cambiarFecha = false, String? fecha}) async {
    await _copiarSiHaceFalta();
    final cambios = <String, Object?>{columna: valor};
    if (columna == 'texto_$idiomaOriginal' && columnas.contains('caracteres')) {
      cambios['caracteres'] = (valor ?? '').runes.length;
    }
    if (cambiarFecha) cambios['fecha'] = fecha;
    final asignaciones = cambios.keys.map((c) => '${_q(c)} = ?').join(', ');
    await _db.rawUpdate(
      'UPDATE ${_q(tabla)} SET $asignaciones WHERE "id" = ?',
      [...cambios.values, id],
    );
  }

  /// Fecha y hora actuales con el formato de los libros,
  /// p. ej. `2026-09-30T11:46:05.123456`.
  static String _fechaActual() {
    final ahora = DateTime.now();
    final micros = (ahora.millisecond * 1000 + ahora.microsecond)
        .toString()
        .padLeft(6, '0');
    return '${ahora.toIso8601String().substring(0, 19)}.$micros';
  }

  /// Ya se ha hecho la copia de seguridad de esta sesión.
  bool _copiaHecha = false;

  /// Guarda una copia del libro en `_programa/copias` la primera vez que se
  /// modifica desde que se abrió (p. ej. `dorian_gray_ultima.db`). Sustituye
  /// a la copia anterior de ese libro.
  Future<void> _copiarSiHaceFalta() async {
    if (_copiaHecha) return;
    final carpeta = _datos.carpetaCopias;
    if (!carpeta.existsSync()) carpeta.createSync(recursive: true);

    final extension = p.extension(ruta);
    final copia = File(p.join(carpeta.path, '${nombre}_ultima$extension'));
    // Primero se copia a un archivo temporal: si algo falla, la copia
    // anterior sigue intacta.
    final temporal = File('${copia.path}.tmp');
    if (temporal.existsSync()) temporal.deleteSync();
    await _db.execute("VACUUM INTO '${temporal.path.replaceAll("'", "''")}'");
    if (copia.existsSync()) copia.deleteSync();
    temporal.renameSync(copia.path);
    _copiaHecha = true;
  }

  // ---------------------------------------------------------------------------
  // Auxiliares
  // ---------------------------------------------------------------------------

  /// Pone comillas a un nombre de tabla o columna para usarlo en SQL.
  /// (Los valores van siempre como parámetros `?`.)
  static String _q(String nombre) => '"${nombre.replaceAll('"', '""')}"';

  /// Tabla `libro` o, si no existe, la primera con columnas `texto_xx`.
  static Future<String> _buscarTabla(Database db) async {
    final filas = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final nombres = filas.map((f) => f['name'].toString()).toList();

    for (final nombre in nombres) {
      if (nombre.toLowerCase() == 'libro') return nombre;
    }
    for (final nombre in nombres) {
      final info = await db.rawQuery('PRAGMA table_info(${_q(nombre)})');
      if (info.any((c) =>
          c['name'].toString().toLowerCase().startsWith('texto_'))) {
        return nombre;
      }
    }
    throw const FormatException('No se encontró la tabla "libro" ni ninguna '
        'tabla con columnas texto_xx.');
  }

  /// Idiomas con texto en al menos un párrafo (una sola consulta).
  static Future<List<String>> _idiomasConTexto(
      Database db, String tabla, List<String> idiomas) async {
    if (idiomas.isEmpty) return [];
    final comprobaciones = idiomas
        .map((i) => "EXISTS(SELECT 1 FROM ${_q(tabla)} "
            "WHERE TRIM(COALESCE(${_q('texto_$i')}, '')) <> '') AS ${_q(i)}")
        .join(', ');
    final fila = (await db.rawQuery('SELECT $comprobaciones')).first;
    return idiomas.where((i) => Parrafo.aEntero(fila[i]) == 1).toList();
  }

  /// Idioma más frecuente en `idioma_original`; si no hay, `en` o el
  /// primero disponible.
  static Future<String> _detectarIdiomaOriginal(Database db, String tabla,
      Set<String> columnas, List<String> idiomas) async {
    if (columnas.contains('idioma_original')) {
      final filas = await db.rawQuery(
        'SELECT LOWER(TRIM(idioma_original)) AS idioma, COUNT(*) AS n '
        'FROM ${_q(tabla)} WHERE idioma_original IS NOT NULL '
        'GROUP BY LOWER(TRIM(idioma_original)) ORDER BY n DESC LIMIT 1',
      );
      if (filas.isNotEmpty) {
        final idioma = (filas.first['idioma'] ?? '').toString();
        if (idiomas.contains(idioma)) return idioma;
      }
    }
    return idiomas.contains('en') ? 'en' : idiomas.first;
  }
}
