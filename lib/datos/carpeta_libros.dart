import 'dart:io';

import 'package:path/path.dart' as p;

import 'datos_programa.dart';

/// Carpetas de libros.
///
/// La carpeta `libros` del programa es la de por defecto y guarda los datos
/// internos (`_programa`). El usuario puede elegir cualquier otra.
class CarpetaLibros {
  CarpetaLibros._();

  static const String nombreCarpeta = 'libros';

  /// Extensiones de archivo que se consideran libros.
  static const Set<String> extensiones = {'.db', '.sqlite', '.sqlite3'};

  /// Número máximo de niveles de subcarpetas en los que se buscan libros.
  static const int profundidadMaxima = 8;

  /// Busca la carpeta `libros` junto al ejecutable, en la carpeta de trabajo
  /// o en las superiores. Si no existe, devuelve la de la carpeta de trabajo.
  static Directory localizar() {
    final carpetaPrograma = File(Platform.resolvedExecutable).parent;
    final candidatas = [
      Directory(p.join(carpetaPrograma.path, nombreCarpeta)),
      Directory(p.join(Directory.current.path, nombreCarpeta)),
    ];

    var carpeta = carpetaPrograma.parent;
    for (var nivel = 0; nivel < 8; nivel++) {
      candidatas.add(Directory(p.join(carpeta.path, nombreCarpeta)));
      if (carpeta.parent.path == carpeta.path) break; // Raíz del disco.
      carpeta = carpeta.parent;
    }

    return candidatas.firstWhere(
      (candidata) => candidata.existsSync(),
      orElse: () => Directory(p.join(Directory.current.path, nombreCarpeta)),
    );
  }

  /// Indica si [ruta] es un libro (por su extensión; excepto Thumbs.db).
  static bool esLibro(String ruta) =>
      extensiones.contains(p.extension(ruta).toLowerCase()) &&
      p.basename(ruta).toLowerCase() != 'thumbs.db';

  /// Subcarpetas que no se revisan: ocultas, del sistema y `_programa`.
  static bool _omitir(String nombre) =>
      nombre.startsWith('.') ||
      nombre.startsWith(r'$') ||
      nombre == DatosPrograma.nombreCarpeta;

  /// Libros de [carpeta] y sus subcarpetas, ordenados por ruta. Las
  /// carpetas sin permiso de lectura se saltan.
  static Future<List<File>> buscarLibros(Directory carpeta) async {
    final libros = <File>[];

    Future<void> recorrer(Directory actual, int nivel) async {
      final subcarpetas = <Directory>[];
      try {
        await for (final entrada in actual.list(followLinks: false)) {
          final nombre = p.basename(entrada.path);
          if (entrada is File && esLibro(nombre)) {
            libros.add(entrada);
          } else if (entrada is Directory && !_omitir(nombre)) {
            subcarpetas.add(entrada);
          }
        }
      } on FileSystemException {
        return;
      }
      if (nivel < profundidadMaxima) {
        for (final subcarpeta in subcarpetas) {
          await recorrer(subcarpeta, nivel + 1);
        }
      }
    }

    if (await carpeta.exists()) await recorrer(carpeta, 0);
    libros.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return libros;
  }
}
