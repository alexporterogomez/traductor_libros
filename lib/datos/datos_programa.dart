import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Entrada del historial: valor de una celda antes de cambiarla.
class VersionAnterior {
  const VersionAnterior(
      this.id, this.texto, this.fechaAnterior, this.fechaNueva);

  /// Id de la entrada en la tabla `historial`.
  final int id;

  /// Valor anterior (texto o JSON de palabras); null si estaba vacía.
  final String? texto;

  /// Fecha del párrafo antes del cambio y la que se le puso con el cambio
  /// (null si el libro no tiene columna `fecha` o el cambio es antiguo).
  final String? fechaAnterior, fechaNueva;
}

/// Base de datos interna del programa: `libros/_programa/traductor.db`.
///
/// - `historial`: valor anterior de cada cambio, para poder revertirlo.
/// - `ajustes`: preferencias (carpeta, último libro, tamaños...).
///
/// Va aparte para no añadir tablas a los libros de la app móvil.
class DatosPrograma {
  DatosPrograma._(this._db, this.carpeta);

  static const String nombreCarpeta = '_programa';
  static const String nombreArchivo = 'traductor.db';

  /// Marca del historial para los cambios de palabras (columna `keys`).
  static const String campoPalabras = 'keys';

  final Database _db;

  /// Carpeta de los datos internos (`libros/_programa`).
  final Directory carpeta;

  /// Carpeta donde se guardan las copias de seguridad de los libros.
  Directory get carpetaCopias => Directory(p.join(carpeta.path, 'copias'));

  /// Abre (o crea) la base de datos interna dentro de [carpetaLibros].
  static Future<DatosPrograma> abrir(Directory carpetaLibros) async {
    final carpeta = Directory(p.join(carpetaLibros.path, nombreCarpeta));
    if (!carpeta.existsSync()) carpeta.createSync(recursive: true);

    final db = await databaseFactoryFfi
        .openDatabase(p.join(carpeta.path, nombreArchivo));
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historial (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libro TEXT NOT NULL,
        id_parrafo INTEGER NOT NULL,
        idioma TEXT NOT NULL,
        texto_anterior TEXT,
        fecha TEXT NOT NULL,
        fecha_anterior TEXT,
        fecha_nueva TEXT
      )
    ''');
    // Columnas añadidas más tarde: se crean si la tabla es de antes.
    final existentes = {
      for (final c in await db.rawQuery('PRAGMA table_info(historial)'))
        c['name'],
    };
    for (final columna in ['fecha_anterior', 'fecha_nueva']) {
      if (!existentes.contains(columna)) {
        await db.execute('ALTER TABLE historial ADD COLUMN $columna TEXT');
      }
    }
    // Índice para localizar rápido las versiones de un párrafo.
    await db.execute('CREATE INDEX IF NOT EXISTS historial_parrafo '
        'ON historial (libro, id_parrafo, idioma)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ajustes (clave TEXT PRIMARY KEY, valor TEXT)');
    return DatosPrograma._(db, carpeta);
  }

  /// Cierra la base de datos interna.
  Future<void> cerrar() => _db.close();

  // ---------------------------------------------------------------------------
  // Historial ([libro] = ruta del libro; [campo] = idioma o [campoPalabras])
  // ---------------------------------------------------------------------------

  /// Guarda [texto] como versión anterior, con la fecha del párrafo antes
  /// y después del cambio. Devuelve el id de la entrada.
  Future<int> anotarVersion(
      String libro, int idParrafo, String campo, String? texto,
      {String? fechaAnterior, String? fechaNueva}) {
    return _db.insert('historial', {
      'libro': libro,
      'id_parrafo': idParrafo,
      'idioma': campo,
      'texto_anterior': texto,
      'fecha': DateTime.now().toIso8601String(),
      'fecha_anterior': fechaAnterior,
      'fecha_nueva': fechaNueva,
    });
  }

  /// Última versión guardada, o null si no hay historial.
  Future<VersionAnterior?> ultimaVersion(
      String libro, int idParrafo, String campo) async {
    final filas = await _db.query(
      'historial',
      columns: ['id', 'texto_anterior', 'fecha_anterior', 'fecha_nueva'],
      where: 'libro = ? AND id_parrafo = ? AND idioma = ?',
      whereArgs: [libro, idParrafo, campo],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (filas.isEmpty) return null;
    final fila = filas.first;
    return VersionAnterior(
      fila['id'] as int,
      fila['texto_anterior']?.toString(),
      fila['fecha_anterior']?.toString(),
      fila['fecha_nueva']?.toString(),
    );
  }

  /// Elimina la entrada [id] del historial.
  Future<void> borrarVersion(int id) =>
      _db.delete('historial', where: 'id = ?', whereArgs: [id]);

  /// Número de versiones anotadas de [campo] en el párrafo.
  Future<int> contarVersiones(String libro, int idParrafo, String campo) async {
    final filas = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM historial '
      'WHERE libro = ? AND id_parrafo = ? AND idioma = ?',
      [libro, idParrafo, campo],
    );
    final n = filas.isEmpty ? null : filas.first['n'];
    return n is int ? n : 0;
  }

  // ---------------------------------------------------------------------------
  // Ajustes
  // ---------------------------------------------------------------------------

  /// Valor guardado para [clave], o null si no existe.
  Future<String?> leer(String clave) async {
    final filas = await _db.query(
      'ajustes',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: [clave],
      limit: 1,
    );
    return filas.isEmpty ? null : filas.first['valor']?.toString();
  }

  /// Guarda [valor] en [clave], sustituyendo el valor anterior si existía.
  Future<void> guardar(String clave, String valor) => _db.insert(
        'ajustes',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
