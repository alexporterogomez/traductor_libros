import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:trina_grid/trina_grid.dart' show TrinaGridStateManager;

import '../datos/base_datos_libro.dart';
import '../datos/carpeta_libros.dart';
import '../datos/datos_programa.dart';
import '../datos/repositorio_libro.dart';
import '../modelos/palabra.dart';
import '../modelos/parrafo.dart';
import '../servicios/servicio_ia.dart';
import '../utilidades/dialogos.dart';
import '../utilidades/idiomas.dart';
import '../widgets/divisor.dart';
import '../widgets/panel_detalle.dart';
import '../widgets/panel_json.dart';
import '../widgets/tabla_palabras.dart';
import '../widgets/tabla_parrafos.dart';
import '../widgets/tarjetas_idiomas.dart';
import 'dialogo_abrir_libro.dart';
import 'dialogo_corregir.dart';

/// Ventana principal: párrafos | tarjetas y editor | palabras | JSON.
///
/// Aquí están el estado y la lógica (libro, párrafo, idioma, guardar,
/// traducir...). Los widgets solo dibujan y avisan con callbacks.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  // Claves de los ajustes guardados en DatosPrograma.
  static const String _ajusteCarpeta = 'carpeta_libros';
  static const String _ajusteUltimoLibro = 'ultimo_libro';
  static const String _ajusteZonas = 'anchos_zonas';
  static const String _ajusteAltoTarjetas = 'alto_tarjetas';

  // Tamaño mínimo de cada zona, en píxeles.
  static const double _minParrafos = 320, _minCentro = 480;
  static const double _minPalabras = 260, _minCapitulos = 180;
  static const double _minTarjetas = 200, _minEditor = 220;

  /// Ancho mínimo; si la ventana es menor, se desplaza en horizontal.
  static const double _minimoTotal = _minParrafos +
      _minCentro +
      _minPalabras +
      _minCapitulos +
      3 * Divisor.grosor;

  final TextEditingController _ctrlTraduccion = TextEditingController();
  final ServicioIA _ia = ServicioIA();

  /// Carpeta que muestra el diálogo de abrir libro.
  Directory _carpeta = CarpetaLibros.localizar();

  /// Base de datos interna (historial y ajustes). Se abre al necesitarla.
  DatosPrograma? _datos;

  // Libro abierto.
  RepositorioLibro? _libro;
  File? _archivoActual;

  /// Párrafos del libro. La tabla se crea de nuevo solo al abrir un libro;
  /// si cambia un texto, se actualiza su fila.
  List<Parrafo> _parrafos = [];

  /// Controlador de la tabla de párrafos (filtros y orden), o null
  /// mientras se carga.
  TrinaGridStateManager? _tablaParrafos;

  /// JSON de capítulos del libro abierto.
  String? _capitulos;

  /// Párrafo seleccionado en la tabla.
  Parrafo? _seleccionado;

  /// Idioma que se edita: una traducción o el original.
  String? _idioma;

  // Traducción.

  /// Textos guardados del párrafo seleccionado, por idioma.
  Map<String, String> _textos = {};

  /// Versiones anteriores de la traducción actual en el historial.
  int _versionesTraduccion = 0;

  // Palabras.

  /// Palabras del párrafo tal como están guardadas en el libro.
  List<Palabra> _palabras = [];

  /// Palabras que muestra la tabla, con las ediciones pendientes de guardar.
  List<Palabra> _palabrasEditadas = [];

  /// Versiones anteriores de las palabras del párrafo en el historial.
  int _versionesPalabras = 0;

  /// Cambia al recargar las palabras (ver [TablaPalabras.revision]).
  int _revisionPalabras = 0;

  bool _cargando = false;
  bool _traduciendo = false;
  bool _generandoPalabras = false;

  /// Hay un guardado en curso (evita guardar dos veces a la vez).
  bool _guardando = false;

  // Tamaño de las zonas, como proporción del espacio disponible.
  double _fParrafos = 0.26;
  double _fPalabras = 0.18;
  double _fCapitulos = 0.14;
  double _fTarjetas = 0.55;

  /// Traducción guardada del párrafo en el idioma que se edita.
  String get _textoGuardado => _textos[_idioma] ?? '';

  /// El cuadro de traducción tiene cambios que aún no se han guardado.
  bool get _hayCambiosTraduccion =>
      _seleccionado != null &&
      _idioma != null &&
      _ctrlTraduccion.text != _textoGuardado;

  /// Las palabras tienen ediciones que aún no se han guardado.
  bool get _hayCambiosPalabras =>
      Palabra.aKeys(_palabrasEditadas) != Palabra.aKeys(_palabras);

  /// Título: el primer párrafo del libro (o el nombre del archivo si es
  /// largo o de cuentos) y el idioma original.
  String get _titulo {
    final libro = _libro;
    if (libro == null) return 'Traductor de libros';
    // En un libro de cuentos el primer párrafo es el título de un solo
    // cuento, así que se usa el nombre del archivo.
    final primero = _parrafos.isEmpty || libro.esCuentos
        ? ''
        : _parrafos.first.original.trim();
    final titulo =
        primero.isNotEmpty && primero.length <= 120 ? primero : libro.nombre;
    return '$titulo  ·  Original: ${nombreIdioma(libro.idiomaOriginal)}';
  }

  /// Párrafos visibles en la tabla (con sus filtros y su orden).
  List<Parrafo> get _parrafosVisibles {
    final tabla = _tablaParrafos;
    if (tabla == null) return _parrafos;
    return [for (final fila in tabla.refRows) fila.data as Parrafo];
  }

  /// Comprueba, tras una espera, que siguen abiertos el mismo libro y
  /// párrafo.
  bool _sigueSeleccionado(RepositorioLibro libro, Parrafo parrafo) =>
      mounted && identical(_libro, libro) && _seleccionado?.id == parrafo.id;

  // ---------------------------------------------------------------------------
  // Ciclo de vida y ajustes
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _cargando = true;
    _iniciar();
  }

  @override
  void dispose() {
    _ctrlTraduccion.dispose();
    _libro?.cerrar();
    _datos?.cerrar();
    super.dispose();
  }

  /// Carga los ajustes y abre el último libro, si existe.
  Future<void> _iniciar() async {
    String? ultimo;
    try {
      final datos = await _datosPrograma();
      Future<double?> proporcion(String clave) async =>
          double.tryParse(await datos.leer(clave) ?? '');

      final carpeta = await datos.leer(_ajusteCarpeta);
      if (carpeta != null) _carpeta = Directory(carpeta);
      ultimo = await datos.leer(_ajusteUltimoLibro);
      final zonas = _leerAnchos(await datos.leer(_ajusteZonas));
      _fParrafos = zonas['parrafos'] ?? _fParrafos;
      _fPalabras = zonas['palabras'] ?? _fPalabras;
      _fCapitulos = zonas['capitulos'] ?? _fCapitulos;
      _fTarjetas = await proporcion(_ajusteAltoTarjetas) ?? _fTarjetas;
    } catch (_) {
      // Si los ajustes no se pueden leer, se usan los valores por defecto.
    }

    if (ultimo != null && File(ultimo).existsSync()) {
      await _abrirLibro(File(ultimo));
    } else if (mounted) {
      setState(() => _cargando = false);
    }
  }

  /// Abre la base de datos interna (siempre en la carpeta del programa).
  Future<DatosPrograma> _datosPrograma() async =>
      _datos ??= await DatosPrograma.abrir(CarpetaLibros.localizar());

  /// Guarda un ajuste en la base de datos interna.
  Future<void> _guardarAjuste(String clave, String valor) async {
    try {
      await _datos?.guardar(clave, valor);
    } catch (_) {
      // Los ajustes no son imprescindibles: un fallo no interrumpe el trabajo.
    }
  }

  /// Convierte un JSON guardado de anchos o proporciones en un mapa.
  static Map<String, double> _leerAnchos(String? json) {
    try {
      final datos = jsonDecode(json ?? '{}');
      if (datos is! Map) return {};
      return {
        for (final entrada in datos.entries)
          if (entrada.value is num)
            entrada.key.toString(): (entrada.value as num).toDouble(),
      };
    } on FormatException {
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Libros
  // ---------------------------------------------------------------------------

  /// Muestra el diálogo para elegir libro y abre el elegido.
  Future<void> _elegirLibro() async {
    if (_cargando) return;
    final elegido = await mostrarDialogo<File>(
      context,
      (_) => DialogoAbrirLibro(
        carpeta: _carpeta,
        libroActual: _archivoActual?.path,
        onCambiarCarpeta: (carpeta) {
          _carpeta = carpeta;
          _guardarAjuste(_ajusteCarpeta, carpeta.path);
        },
      ),
    );
    if (elegido != null) await _cambiarLibro(elegido);
  }

  /// Abre [archivo] en su primer párrafo, con el idioma original. Si falla,
  /// sigue abierto el anterior.
  Future<void> _abrirLibro(File archivo) async {
    if (!_cargando) {
      if (!mounted) return;
      setState(() => _cargando = true);
    }

    final anterior = _libro;
    final nombreArchivo = p.basename(archivo.path);
    try {
      final datos = await _datosPrograma();
      final libro = await BaseDatosLibro.abrir(archivo.path, datos);
      final parrafos = await libro.cargarParrafos();
      final capitulos = await libro.leerCapitulos();

      if (!mounted) {
        await libro.cerrar();
        return;
      }
      setState(() {
        _libro = libro;
        _archivoActual = archivo;
        _parrafos = parrafos;
        _tablaParrafos = null;
        _capitulos = capitulos;
        _idioma = libro.idiomaOriginal;
        _seleccionado = null;
        _textos = {};
        _versionesTraduccion = 0;
        _ctrlTraduccion.clear();
        _cargarPalabras([], 0);
        _cargando = false;
      });
      await anterior?.cerrar();
      await _guardarAjuste(_ajusteUltimoLibro, archivo.path);

      // Se empieza en el primer párrafo, con el idioma original.
      if (parrafos.isNotEmpty) {
        await _mostrarParrafo(libro, parrafos.first, libro.idiomaOriginal);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _mostrarError('No se pudo abrir «$nombreArchivo».\n\n${explicarError(e)}');
    }
  }

  /// Cambia de libro (pregunta si hay cambios sin guardar).
  Future<void> _cambiarLibro(File archivo) async {
    final actual = _archivoActual;
    if (actual != null && p.equals(archivo.path, actual.path)) return;
    if (!await _confirmarDescartar()) return;
    await _abrirLibro(archivo);
  }

  // ---------------------------------------------------------------------------
  // Párrafos e idiomas
  // ---------------------------------------------------------------------------

  /// Selecciona [parrafo]. Devuelve false si no se ha podido.
  Future<bool> _seleccionar(Parrafo parrafo) async {
    final libro = _libro;
    if (libro == null) return false;
    if (parrafo.id == _seleccionado?.id) return true;
    if (!await _confirmarDescartar()) return false;
    await _mostrarParrafo(libro, parrafo, _idioma ?? libro.idiomaOriginal);
    return _seleccionado?.id == parrafo.id;
  }

  /// Va al párrafo anterior (-1) o siguiente (+1) de los visibles.
  void _irRelativo(int salto) {
    final visibles = _parrafosVisibles;
    final actual =
        visibles.indexWhere((parrafo) => parrafo.id == _seleccionado?.id);
    // Si el actual no está visible, va al primero.
    final nuevo = actual + salto;
    if (nuevo < 0 || nuevo >= visibles.length) return;
    _seleccionar(visibles[nuevo]);
  }

  /// Tabla de párrafos lista: se guarda su controlador.
  void _alCargarTabla(TrinaGridStateManager tabla) =>
      setState(() => _tablaParrafos = tabla);

  /// Al filtrar u ordenar la tabla se actualizan los botones ▲▼.
  void _alCambiarVista() => setState(() {});

  /// Cambia el idioma que se edita (clic en una tarjeta).
  Future<void> _cambiarIdioma(String idioma) async {
    final libro = _libro;
    if (libro == null || idioma == _idioma) return;
    // Las palabras no dependen del idioma: solo se comprueba la traducción.
    if (!await _confirmarDescartar(incluirPalabras: false) || !mounted) return;

    final parrafo = _seleccionado;
    if (parrafo == null) {
      setState(() => _idioma = idioma);
    } else {
      await _mostrarParrafo(libro, parrafo, idioma);
    }
  }

  /// Lee y muestra el párrafo en [idioma]. Si es el mismo párrafo, conserva
  /// las palabras editadas.
  Future<void> _mostrarParrafo(
      RepositorioLibro libro, Parrafo parrafo, String idioma) async {
    try {
      final textos = await libro.leerTextos(parrafo.id);
      final palabras = await libro.leerPalabras(parrafo.id);
      final versionesPalabras = await libro.contarVersionesPalabras(parrafo.id);
      final versionesTraduccion =
          await libro.contarVersionesTraduccion(parrafo.id, idioma);
      // Si mientras tanto se ha abierto otro libro, el resultado ya no vale.
      if (!mounted || !identical(_libro, libro)) return;
      final mismoParrafo = parrafo.id == _seleccionado?.id;
      setState(() {
        _seleccionado = parrafo;
        _idioma = idioma;
        _textos = textos;
        _versionesTraduccion = versionesTraduccion;
        _ctrlTraduccion.text = textos[idioma] ?? '';
        if (!mismoParrafo) _cargarPalabras(palabras, versionesPalabras);
      });
    } catch (e) {
      _mostrarError(
          'No se pudo leer el párrafo ${parrafo.id}.\n\n${explicarError(e)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Corregir el texto original
  // ---------------------------------------------------------------------------

  /// Abre el diálogo Corregir.
  Future<void> _abrirCorreccion() async {
    final libro = _libro;
    if (libro == null) return;
    // Si se está editando el original, primero se descartan sus cambios
    // sin guardar (si no, al guardar pisarían las correcciones).
    if (_idioma == libro.idiomaOriginal) {
      if (!await _confirmarDescartar(incluirPalabras: false) || !mounted) {
        return;
      }
      setState(() => _ctrlTraduccion.text = _textoGuardado);
    }
    await mostrarDialogo<void>(
      context,
      (_) => DialogoCorregir(
        parrafos: _parrafos,
        nombreIdioma: nombreIdioma(libro.idiomaOriginal),
        idInicial: _seleccionado?.id,
        onCorregir: (parrafo, texto) async {
          await libro.corregirOriginal(parrafo.id, texto);
          return _alCambiarOriginal(libro, parrafo, texto);
        },
        onDeshacer: (parrafo) async {
          final restaurado = await libro.revertirOriginal(parrafo.id);
          if (restaurado == null) return null;
          return _alCambiarOriginal(libro, parrafo, restaurado);
        },
      ),
    );
  }

  /// Tras corregir o deshacer en el diálogo: actualiza la tabla y, si es
  /// el párrafo que se ve con el original elegido, también el editor.
  Future<Parrafo> _alCambiarOriginal(
      RepositorioLibro libro, Parrafo parrafo, String texto) async {
    final nuevo =
        await _refrescarParrafo(libro, parrafo.id, original: texto) ??
            parrafo.conOriginal(texto);
    if (_seleccionado?.id == parrafo.id && _idioma == libro.idiomaOriginal) {
      await _actualizarTraduccion(libro, nuevo, libro.idiomaOriginal, texto);
    }
    return nuevo;
  }

  /// Tras guardar o revertir: pone en el párrafo [id] su fecha actual y, si
  /// se indica, su nuevo texto [original]. Devuelve el párrafo, o null si ya
  /// se ha cambiado de libro.
  Future<Parrafo?> _refrescarParrafo(RepositorioLibro libro, int id,
      {String? original}) async {
    final fecha = await libro.leerFecha(id);
    if (!mounted || !identical(_libro, libro)) return null;
    final indice = _parrafos.indexWhere((parrafo) => parrafo.id == id);
    if (indice < 0) return null;
    var nuevo = _parrafos[indice].conFecha(fecha);
    if (original != null) nuevo = nuevo.conOriginal(original);
    return _sustituirParrafo(libro, nuevo);
  }

  /// Sustituye un párrafo de la lista (y de la tabla) y lo devuelve.
  Parrafo _sustituirParrafo(RepositorioLibro libro, Parrafo nuevo) {
    if (mounted && identical(_libro, libro)) {
      setState(() {
        _parrafos = [
          for (final parrafo in _parrafos)
            parrafo.id == nuevo.id ? nuevo : parrafo,
        ];
        if (_seleccionado?.id == nuevo.id) {
          _seleccionado = nuevo;
          _textos = {..._textos, libro.idiomaOriginal: nuevo.original};
        }
      });
    }
    return nuevo;
  }

  // ---------------------------------------------------------------------------
  // Traducción: traducir, guardar y revertir
  // ---------------------------------------------------------------------------

  /// Pide la traducción a la IA y la deja sin guardar para revisarla.
  Future<void> _traducir() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    final idioma = _idioma;
    if (libro == null ||
        parrafo == null ||
        idioma == null ||
        idioma == libro.idiomaOriginal ||
        _traduciendo) {
      return;
    }
    if (_hayCambiosTraduccion) {
      final seguir = await _preguntar(
        titulo: 'Cambios sin guardar',
        mensaje: 'La traducción de la IA sustituirá a lo que has escrito y '
            'aún no has guardado. ¿Continuar?',
        textoSi: 'Continuar',
      );
      if (!seguir || !mounted) return;
    }

    setState(() => _traduciendo = true);
    try {
      final traduccion = await _ia.traducir(
        texto: parrafo.original,
        idiomaOrigen: libro.idiomaOriginal,
        idiomaDestino: idioma,
      );
      // Si se ha cambiado de libro, párrafo o idioma, se descarta.
      if (_sigueSeleccionado(libro, parrafo) && _idioma == idioma) {
        setState(() => _ctrlTraduccion.text = traduccion);
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _traduciendo = false);
    }
  }

  /// Guarda en el libro el texto del cuadro de traducción.
  Future<void> _guardarTraduccion() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    final idioma = _idioma;
    if (libro == null ||
        parrafo == null ||
        idioma == null ||
        !_hayCambiosTraduccion ||
        _traduciendo ||
        _guardando) {
      return;
    }

    final texto = _ctrlTraduccion.text;
    _guardando = true;
    try {
      await libro.guardarTraduccion(parrafo.id, idioma, texto);
      await _actualizarTraduccion(libro, parrafo, idioma, texto);
    } catch (e) {
      _mostrarError('No se pudo guardar la traducción.\n\n${explicarError(e)}');
    } finally {
      _guardando = false;
    }
  }

  /// Descarta los cambios sin guardar o, si no hay, vuelve a la versión
  /// anterior (previa confirmación).
  Future<void> _revertirTraduccion() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    final idioma = _idioma;
    if (libro == null || parrafo == null || idioma == null) return;

    if (_hayCambiosTraduccion) {
      setState(() => _ctrlTraduccion.text = _textoGuardado);
      return;
    }
    if (_versionesTraduccion == 0) return;

    final seguir = await _preguntar(
      titulo: 'Revertir traducción',
      mensaje: 'Se restaurará la versión anterior guardada de la traducción '
          '(${nombreIdioma(idioma)}) del párrafo ${parrafo.id}. ¿Continuar?',
      textoSi: 'Revertir',
    );
    if (!seguir) return;

    try {
      final restaurado = await libro.revertirTraduccion(parrafo.id, idioma);
      if (restaurado != null) {
        await _actualizarTraduccion(libro, parrafo, idioma, restaurado);
      }
    } catch (e) {
      _mostrarError('No se pudo revertir la traducción.\n\n${explicarError(e)}');
    }
  }

  /// Actualiza el texto guardado y las versiones tras guardar o revertir.
  Future<void> _actualizarTraduccion(RepositorioLibro libro, Parrafo parrafo,
      String idioma, String texto) async {
    // Fecha (y texto, si es el original) en la tabla, aunque ya se haya
    // pasado a otro párrafo.
    await _refrescarParrafo(libro, parrafo.id,
        original: idioma == libro.idiomaOriginal ? texto : null);
    final versiones = await libro.contarVersionesTraduccion(parrafo.id, idioma);
    if (!_sigueSeleccionado(libro, parrafo)) return;
    setState(() {
      _textos = {..._textos, idioma: texto};
      _ctrlTraduccion.text = texto;
      _versionesTraduccion = versiones;
    });
  }

  // ---------------------------------------------------------------------------
  // Palabras: editar, guardar y revertir
  // ---------------------------------------------------------------------------

  /// Carga [palabras] como guardadas y crea de nuevo la tabla. Llamar
  /// dentro de `setState`.
  void _cargarPalabras(List<Palabra> palabras, int versiones) {
    _palabras = palabras;
    _palabrasEditadas = palabras;
    _versionesPalabras = versiones;
    _revisionPalabras++;
  }

  /// Pide a la IA de nuevo los lemas y tipos del párrafo y los deja en la
  /// tabla sin guardar, para revisarlos antes de pulsar Guardar.
  Future<void> _generarPalabras() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    if (libro == null ||
        parrafo == null ||
        _palabrasEditadas.isEmpty ||
        _generandoPalabras) {
      return;
    }
    if (_hayCambiosPalabras) {
      final seguir = await _preguntar(
        titulo: 'Cambios sin guardar',
        mensaje: 'Las palabras de la IA sustituirán a las ediciones que aún no '
            'has guardado. ¿Continuar?',
        textoSi: 'Continuar',
      );
      if (!seguir || !mounted) return;
    }

    setState(() => _generandoPalabras = true);
    try {
      final palabras = await _ia.lematizar(
        texto: parrafo.original,
        idioma: libro.idiomaOriginal,
        palabras: _palabrasEditadas,
      );
      // Si mientras tanto se cambió de libro o de párrafo, se descarta.
      if (_sigueSeleccionado(libro, parrafo)) {
        setState(() {
          _palabrasEditadas = palabras;
          _revisionPalabras++;
        });
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _generandoPalabras = false);
    }
  }

  /// Sustituye la palabra editada (se identifica por su posición).
  void _editarPalabra(Palabra editada) {
    setState(() => _palabrasEditadas = [
          for (final palabra in _palabrasEditadas)
            palabra.indice == editada.indice ? editada : palabra,
        ]);
  }

  /// Guarda en el libro las palabras editadas del párrafo seleccionado.
  Future<void> _guardarPalabras() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    if (libro == null ||
        parrafo == null ||
        !_hayCambiosPalabras ||
        _guardando) {
      return;
    }

    final palabras = _palabrasEditadas;
    _guardando = true;
    try {
      await libro.guardarPalabras(parrafo.id, palabras);
      await _refrescarParrafo(libro, parrafo.id); // Nueva fecha.
      final versiones = await libro.contarVersionesPalabras(parrafo.id);
      // La tabla ya las muestra: no se crea de nuevo.
      if (!_sigueSeleccionado(libro, parrafo)) return;
      setState(() {
        _palabras = palabras;
        _versionesPalabras = versiones;
      });
    } catch (e) {
      _mostrarError('No se pudieron guardar las palabras.\n\n${explicarError(e)}');
    } finally {
      _guardando = false;
    }
  }

  /// Descarta las ediciones de palabras o, si no hay, vuelve a la versión
  /// anterior (previa confirmación).
  Future<void> _revertirPalabras() async {
    final libro = _libro;
    final parrafo = _seleccionado;
    if (libro == null || parrafo == null) return;

    if (_hayCambiosPalabras) {
      setState(() => _cargarPalabras(_palabras, _versionesPalabras));
      return;
    }
    if (_versionesPalabras == 0) return;

    final seguir = await _preguntar(
      titulo: 'Revertir palabras',
      mensaje: 'Se restaurará la versión anterior guardada de las palabras '
          'del párrafo ${parrafo.id}. ¿Continuar?',
      textoSi: 'Revertir',
    );
    if (!seguir) return;

    try {
      final restauradas = await libro.revertirPalabras(parrafo.id);
      if (restauradas == null) return;
      await _refrescarParrafo(libro, parrafo.id); // Fecha anterior.
      final versiones = await libro.contarVersionesPalabras(parrafo.id);
      if (!_sigueSeleccionado(libro, parrafo)) return;
      setState(() => _cargarPalabras(restauradas, versiones));
    } catch (e) {
      _mostrarError('No se pudieron revertir las palabras.\n\n${explicarError(e)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Diálogos
  // ---------------------------------------------------------------------------

  /// Si hay cambios sin guardar, pregunta si se descartan. Devuelve true
  /// si se puede continuar.
  Future<bool> _confirmarDescartar({bool incluirPalabras = true}) async {
    final traduccion = _hayCambiosTraduccion;
    final palabras = incluirPalabras && _hayCambiosPalabras;
    if (!traduccion && !palabras) return true;

    final que = traduccion && palabras
        ? 'la traducción y en las palabras'
        : (traduccion ? 'la traducción' : 'las palabras');
    return _preguntar(
      titulo: 'Cambios sin guardar',
      mensaje: 'Hay cambios sin guardar en $que de este párrafo. '
          '¿Quieres descartarlos?',
      textoSi: 'Descartar',
    );
  }

  /// Pregunta de confirmación (false si la ventana ya no existe).
  Future<bool> _preguntar({
    required String titulo,
    required String mensaje,
    required String textoSi,
  }) async {
    if (!mounted) return false;
    return preguntar(context,
        titulo: titulo, mensaje: mensaje, textoSi: textoSi);
  }

  /// Muestra un mensaje de error si la ventana sigue disponible.
  void _mostrarError(String mensaje) {
    if (mounted) mostrarError(context, mensaje);
  }

  // ---------------------------------------------------------------------------
  // Divisores
  // ---------------------------------------------------------------------------

  /// Ajusta [proporcion] para que las dos zonas respeten su tamaño mínimo.
  static double _limitar(
      double proporcion, double total, double minimoA, double minimoB) {
    final util = total - Divisor.grosor;
    if (util <= minimoA + minimoB) return 0.5;
    return proporcion.clamp(minimoA / util, 1 - minimoB / util).toDouble();
  }

  /// Nueva proporción tras arrastrar un divisor [delta] píxeles.
  static double _mover(double proporcion, double delta, double total,
      double minimoA, double minimoB) {
    final actual = _limitar(proporcion, total, minimoA, minimoB);
    return _limitar(
        actual + delta / (total - Divisor.grosor), total, minimoA, minimoB);
  }

  /// Anchos de las columnas de párrafos, palabras y JSON (la central ocupa
  /// el resto), reducidos si no cabe la central.
  (double, double, double) _anchosZonas(double util) {
    var parrafos = math.max(_minParrafos, _fParrafos * util);
    var palabras = math.max(_minPalabras, _fPalabras * util);
    var capitulos = math.max(_minCapitulos, _fCapitulos * util);

    final exceso = parrafos + palabras + capitulos + _minCentro - util;
    if (exceso > 0) {
      final margen = (parrafos - _minParrafos) +
          (palabras - _minPalabras) +
          (capitulos - _minCapitulos);
      final factor = margen <= 0 ? 0.0 : math.max(0.0, 1 - exceso / margen);
      parrafos = _minParrafos + (parrafos - _minParrafos) * factor;
      palabras = _minPalabras + (palabras - _minPalabras) * factor;
      capitulos = _minCapitulos + (capitulos - _minCapitulos) * factor;
    }
    return (parrafos, palabras, capitulos);
  }

  /// Mueve un divisor vertical (0, 1 o 2, de izquierda a derecha). No hace
  /// nada si alguna zona quedaría por debajo de su mínimo.
  void _moverDivisor(int posicion, double delta, double util) {
    var (parrafos, palabras, capitulos) = _anchosZonas(util);
    switch (posicion) {
      case 0:
        parrafos += delta;
      case 1:
        palabras -= delta;
      case 2:
        palabras += delta;
        capitulos -= delta;
    }
    final centro = util - parrafos - palabras - capitulos;
    if (parrafos < _minParrafos ||
        palabras < _minPalabras ||
        capitulos < _minCapitulos ||
        centro < _minCentro) {
      return;
    }
    setState(() {
      _fParrafos = parrafos / util;
      _fPalabras = palabras / util;
      _fCapitulos = capitulos / util;
    });
  }

  /// Guarda las proporciones de las columnas al soltar un divisor.
  void _guardarZonas() {
    _guardarAjuste(
      _ajusteZonas,
      jsonEncode({
        'parrafos': _fParrafos,
        'palabras': _fPalabras,
        'capitulos': _fCapitulos,
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Atajos de teclado para toda la ventana.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _guardarTraduccion,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _elegirLibro,
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () =>
            _irRelativo(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () =>
            _irRelativo(-1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_titulo, overflow: TextOverflow.ellipsis),
            actions: [
              _botonLibro(),
              const SizedBox(width: 8),
              _menuServidor(),
              const SizedBox(width: 12),
            ],
          ),
          body: _cuerpo(context),
        ),
      ),
    );
  }

  /// Botón con el libro abierto; abre el diálogo para elegir otro.
  Widget _botonLibro() {
    return Tooltip(
      message: 'Abrir libro (Ctrl + O)',
      child: InkWell(
        onTap: _elegirLibro,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book, size: 20),
              const SizedBox(width: 8),
              Text(_libro?.nombre ?? 'Abrir libro'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  /// Menú para elegir el servidor de IA.
  Widget _menuServidor() {
    return _menu(
      tooltip: 'Servidor de IA',
      icono: Icons.dns_outlined,
      texto: 'IA: ${_ia.tipo}',
      opciones: [
        for (final servidor in ServicioIA.tipos)
          _opcion(
            servidor,
            '$servidor  (${ServicioIA(tipo: servidor).direccion})',
            servidor == _ia.tipo
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
      ],
      onElegir: (servidor) => setState(() => _ia.configurar(servidor)),
    );
  }

  /// Botón de menú desplegable con icono y texto.
  Widget _menu({
    required String tooltip,
    required IconData icono,
    required String texto,
    required List<PopupMenuEntry<String>> opciones,
    required ValueChanged<String> onElegir,
  }) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onElegir,
      itemBuilder: (_) => opciones,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 20),
            const SizedBox(width: 8),
            Text(texto),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  /// Opción de menú con icono.
  PopupMenuItem<String> _opcion(String valor, String texto, IconData icono) {
    return PopupMenuItem<String>(
      value: valor,
      child: Row(
        children: [
          Icon(icono, size: 20),
          const SizedBox(width: 12),
          Text(texto),
        ],
      ),
    );
  }

  /// Contenido: las cuatro zonas con sus divisores.
  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final libro = _libro;
    if (libro == null) return _sinLibro(context);

    final seleccionado = _seleccionado;
    final visibles = _parrafosVisibles;
    final indice =
        visibles.indexWhere((parrafo) => parrafo.id == seleccionado?.id);
    final tabla = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_parrafos.length} párrafos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Tooltip(
              message: 'Corregir una palabra en el texto original',
              child: FilledButton.tonalIcon(
                onPressed: _abrirCorreccion,
                icon: const Icon(Icons.spellcheck),
                label: const Text('Corregir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TablaParrafos(
            // Tabla nueva para cada libro abierto.
            key: ObjectKey(libro),
            parrafos: _parrafos,
            idSeleccionado: seleccionado?.id,
            onCargada: _alCargarTabla,
            onCambiarVista: _alCambiarVista,
            mostrarCuento: libro.esCuentos,
            onSeleccionar: _seleccionar,
          ),
        ),
      ],
    );
    final tarjetas = TarjetasIdiomas(
      idiomas: libro.idiomas,
      idiomaOriginal: libro.idiomaOriginal,
      idiomaSeleccionado: _idioma,
      textos: _textos,
      cambiosSinGuardar: _hayCambiosTraduccion,
      onSeleccionar: _cambiarIdioma,
    );
    final detalle = PanelDetalle(
      parrafo: seleccionado,
      idiomaDestino: _idioma ?? libro.idiomaOriginal,
      esOriginal: _idioma == libro.idiomaOriginal,
      controladorTraduccion: _ctrlTraduccion,
      hayCambios: _hayCambiosTraduccion,
      traduccionVacia: _textoGuardado.trim().isEmpty,
      traduciendo: _traduciendo,
      versionesAnteriores: _versionesTraduccion,
      hayAnterior: indice > 0,
      haySiguiente: indice < visibles.length - 1,
      onAnterior: () => _irRelativo(-1),
      onSiguiente: () => _irRelativo(1),
      onTextoEditado: () => setState(() {}),
      onTraducir: _traducir,
      onGuardar: _guardarTraduccion,
      onRevertir: _revertirTraduccion,
    );
    final palabras = TablaPalabras(
      revision: _revisionPalabras,
      palabras: _palabrasEditadas,
      hayCambios: _hayCambiosPalabras,
      versionesAnteriores: _versionesPalabras,
      mensajeVacio: seleccionado == null
          ? 'Selecciona un párrafo'
          : 'Este párrafo no tiene palabras (keys)',
      onEditar: _editarPalabra,
      onGuardar: _guardarPalabras,
      onRevertir: _revertirPalabras,
      generando: _generandoPalabras,
      onGenerar: _generarPalabras,
    );
    final capitulos = PanelJson(
      capitulos: _capitulos,
      palabras: _palabrasEditadas,
    );

    return LayoutBuilder(
      builder: (context, restricciones) {
        // Si no caben los mínimos, se desplaza en horizontal.
        final ancho = math.max(restricciones.maxWidth, _minimoTotal);
        final util = ancho - 3 * Divisor.grosor;
        final (anchoParrafos, anchoPalabras, anchoCapitulos) =
            _anchosZonas(util);
        final alto = restricciones.maxHeight;
        final altoTarjetas = (alto - Divisor.grosor) *
            _limitar(_fTarjetas, alto, _minTarjetas, _minEditor);

        Widget zona(double anchoZona, Widget hijo) => SizedBox(
              width: anchoZona,
              child: Padding(padding: const EdgeInsets.all(8), child: hijo),
            );
        Widget divisor(int posicion) => Divisor(
              vertical: true,
              onArrastrar: (delta) => _moverDivisor(posicion, delta, util),
              onSoltar: _guardarZonas,
            );

        // Columna central: tarjetas arriba y editor abajo.
        final centro = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: altoTarjetas, child: tarjetas),
            Divisor(
              vertical: false,
              onArrastrar: (delta) => setState(() => _fTarjetas =
                  _mover(_fTarjetas, delta, alto, _minTarjetas, _minEditor)),
              onSoltar: () =>
                  _guardarAjuste(_ajusteAltoTarjetas, '$_fTarjetas'),
            ),
            Expanded(child: detalle),
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                zona(anchoParrafos, tabla),
                divisor(0),
                Expanded(child: centro),
                divisor(1),
                zona(anchoPalabras, palabras),
                divisor(2),
                zona(anchoCapitulos, capitulos),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Contenido cuando no hay ningún libro abierto: botón para elegir uno.
  Widget _sinLibro(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 56, color: tema.colorScheme.primary),
          const SizedBox(height: 16),
          Text('No hay ningún libro abierto', style: tema.textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _elegirLibro,
            icon: const Icon(Icons.folder_open),
            label: const Text('Abrir libro…'),
          ),
        ],
      ),
    );
  }
}
