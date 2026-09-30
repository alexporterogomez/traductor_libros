/// Idiomas conocidos: código → (nombre en español, nombre en inglés).
/// Para añadir un idioma basta con una línea.
const Map<String, (String, String)> _idiomas = {
  'en': ('Inglés', 'English'),
  'es': ('Español', 'Spanish'),
  'de': ('Alemán', 'German'),
  'fr': ('Francés', 'French'),
  'it': ('Italiano', 'Italian'),
  'pt': ('Portugués', 'Portuguese'),
  'ru': ('Ruso', 'Russian'),
  'uk': ('Ucraniano', 'Ukrainian'),
  'pl': ('Polaco', 'Polish'),
  'tr': ('Turco', 'Turkish'),
  'zh': ('Chino', 'Chinese'),
  'ja': ('Japonés', 'Japanese'),
  'ko': ('Coreano', 'Korean'),
  'ar': ('Árabe', 'Arabic'),
  'nl': ('Neerlandés', 'Dutch'),
  'sv': ('Sueco', 'Swedish'),
  'ro': ('Rumano', 'Romanian'),
  'ca': ('Catalán', 'Catalan'),
  'gl': ('Gallego', 'Galician'),
  'eu': ('Euskera', 'Basque'),
};

/// Códigos no estándar que usan algunos libros y su equivalente.
const Map<String, String> _alias = {'ch': 'zh'};

/// Código en minúsculas y con los alias sustituidos (`CH` → `zh`).
String _normalizar(String codigo) {
  final c = codigo.toLowerCase();
  return _alias[c] ?? c;
}

/// Nombre en español (`es` → "Español").
String nombreIdioma(String codigo) =>
    _idiomas[_normalizar(codigo)]?.$1 ?? codigo.toUpperCase();

/// Nombre en inglés (`es` → "Spanish").
String nombreIdiomaEnIngles(String codigo) =>
    _idiomas[_normalizar(codigo)]?.$2 ?? codigo;
