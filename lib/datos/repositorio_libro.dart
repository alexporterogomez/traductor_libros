import '../modelos/palabra.dart';
import '../modelos/parrafo.dart';

/// Operaciones que la pantalla necesita sobre un libro.
///
/// La implementación actual es `BaseDatosLibro` (SQLite). Cada cambio
/// guardado deja el valor anterior en el historial para poder revertirlo.
abstract class RepositorioLibro {
  /// Nombre del libro que se muestra al usuario.
  String get nombre;

  /// Código del idioma original del libro (por ejemplo, `en`).
  String get idiomaOriginal;

  /// El libro es de cuentos: tiene la columna `id_cuento`.
  bool get esCuentos;


  /// Idiomas con texto en el libro, incluido el original.
  List<String> get idiomas;

  /// Todos los párrafos del libro, ordenados por id.
  Future<List<Parrafo>> cargarParrafos();

  /// Fecha del párrafo (columna `fecha`), o null si no tiene.
  Future<String?> leerFecha(int id);

  /// Texto del párrafo en cada idioma ('' si no está traducido).
  Future<Map<String, String>> leerTextos(int id);

  /// JSON de capítulos (en los cuentos, los títulos de cada cuento), o null
  /// si el libro no lo tiene.
  Future<String?> leerCapitulos();

  // ---------------------------------------------------------------------------
  // Texto original
  // ---------------------------------------------------------------------------

  /// Cambia el texto original del párrafo [id].
  Future<void> corregirOriginal(int id, String texto);

  /// Deshace el último cambio del original. Devuelve el texto o null.
  Future<String?> revertirOriginal(int id);

  // ---------------------------------------------------------------------------
  // Traducciones
  // ---------------------------------------------------------------------------

  /// Guarda [texto] como traducción del párrafo [id] en [idioma].
  Future<void> guardarTraduccion(int id, String idioma, String texto);

  /// Vuelve a la versión anterior. Devuelve el texto o null.
  Future<String?> revertirTraduccion(int id, String idioma);

  /// Número de versiones anteriores de la traducción.
  Future<int> contarVersionesTraduccion(int id, String idioma);

  // ---------------------------------------------------------------------------
  // Palabras
  // ---------------------------------------------------------------------------

  /// Palabras del párrafo [id] ([] si el libro no las tiene).
  Future<List<Palabra>> leerPalabras(int id);

  /// Sustituye las palabras del párrafo [id] por [palabras].
  Future<void> guardarPalabras(int id, List<Palabra> palabras);

  /// Vuelve a la versión anterior. Devuelve las palabras o null.
  Future<List<Palabra>?> revertirPalabras(int id);

  /// Número de versiones anteriores de las palabras del párrafo [id].
  Future<int> contarVersionesPalabras(int id);

  /// Libera los recursos del libro (cierra la base de datos).
  Future<void> cerrar();
}
