import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../datos/carpeta_libros.dart';
import '../utilidades/dialogos.dart';

/// Diálogo para elegir el libro que se abre.
///
/// Muestra todos los libros de la carpeta principal y de sus subcarpetas,
/// agrupados por carpeta. Cada carpeta se despliega o se pliega con un
/// clic. El buscador filtra por nombre de libro o de carpeta.
///
/// Un clic sobre un libro cierra el diálogo y lo devuelve. Si se cancela,
/// devuelve null.
class DialogoAbrirLibro extends StatefulWidget {
  const DialogoAbrirLibro({
    super.key,
    required this.carpeta,
    required this.libroActual,
    required this.onCambiarCarpeta,
  });

  /// Carpeta principal de libros con la que se abre el diálogo.
  final Directory carpeta;

  /// Ruta del libro abierto (se marca en la lista), o null si no hay ninguno.
  final String? libroActual;

  /// Se llama cuando el usuario elige otra carpeta, para recordarla.
  final ValueChanged<Directory> onCambiarCarpeta;

  @override
  State<DialogoAbrirLibro> createState() => _DialogoAbrirLibroState();
}

class _DialogoAbrirLibroState extends State<DialogoAbrirLibro> {
  /// Carpetas desplegadas. Se recuerdan mientras el programa está abierto.
  static final Set<String> _desplegadas = {};

  final TextEditingController _ctrlBusqueda = TextEditingController();

  /// Carpeta principal elegida.
  late Directory _carpeta = widget.carpeta;

  /// Libros de cada carpeta (ruta de la carpeta → libros por nombre).
  Map<String, List<File>> _grupos = {};

  /// Carpetas con libros, en orden (la principal primero).
  List<String> _carpetas = [];

  int _total = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  /// Busca todos los libros y los agrupa por carpeta.
  Future<void> _cargar() async {
    final carpeta = _carpeta;
    final libros = await CarpetaLibros.buscarLibros(carpeta);
    // Si mientras tanto se ha elegido otra carpeta, el resultado ya no vale.
    if (!mounted || !identical(carpeta, _carpeta)) return;

    final grupos = <String, List<File>>{};
    for (final libro in libros) {
      grupos.putIfAbsent(libro.parent.path, () => []).add(libro);
      // La carpeta del libro abierto empieza desplegada.
      final actual = widget.libroActual;
      if (actual != null && p.equals(libro.path, actual)) {
        _desplegadas.add(libro.parent.path);
      }
    }
    for (final lista in grupos.values) {
      lista.sort((a, b) =>
          _nombre(a).toLowerCase().compareTo(_nombre(b).toLowerCase()));
    }
    final carpetas = grupos.keys.toList()
      ..sort((a, b) {
        if (p.equals(a, carpeta.path)) return -1;
        if (p.equals(b, carpeta.path)) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    setState(() {
      _grupos = grupos;
      _carpetas = carpetas;
      _total = libros.length;
      _cargando = false;
    });
  }

  /// Vuelve a buscar los libros (por si se han añadido o borrado archivos).
  void _actualizar() {
    setState(() => _cargando = true);
    _cargar();
  }

  /// Abre el selector de carpetas de Windows para elegir otra carpeta.
  Future<void> _cambiarCarpeta() async {
    String? ruta;
    try {
      ruta = await FilePicker.getDirectoryPath(
        dialogTitle: 'Elegir carpeta de libros',
        initialDirectory: _carpeta.path,
      );
    } catch (e) {
      if (mounted) {
        mostrarError(context, 'No se pudo abrir el selector de carpetas.\n\n$e');
      }
      return;
    }
    if (ruta == null || !mounted) return;

    final carpeta = Directory(ruta);
    _ctrlBusqueda.clear();
    setState(() {
      _carpeta = carpeta;
      _grupos = {};
      _carpetas = [];
      _cargando = true;
    });
    widget.onCambiarCarpeta(carpeta);
    _cargar();
  }

  /// Despliega o pliega una carpeta.
  void _alternar(String carpeta) => setState(() {
        if (!_desplegadas.remove(carpeta)) _desplegadas.add(carpeta);
      });

  /// Despliega o pliega todas las carpetas.
  void _desplegarTodo(bool desplegar) => setState(() {
        desplegar
            ? _desplegadas.addAll(_carpetas)
            : _desplegadas.removeAll(_carpetas);
      });

  /// Nombre del libro sin extensión.
  static String _nombre(File libro) => p.basenameWithoutExtension(libro.path);

  /// Nombre de una carpeta respecto a la principal ("Inglés › Cuentos").
  String _nombreCarpeta(String carpeta) {
    final relativa = p.relative(carpeta, from: _carpeta.path);
    if (relativa == '.') return 'Carpeta principal';
    return p.split(relativa).join(' › ');
  }

  /// Elementos de la lista: cada carpeta (String) seguida de sus libros
  /// (File) si está desplegada. Al buscar se muestran todas desplegadas.
  List<Object> _elementos() {
    final busqueda = _ctrlBusqueda.text.trim().toLowerCase();
    final elementos = <Object>[];
    for (final carpeta in _carpetas) {
      var libros = _grupos[carpeta]!;
      if (busqueda.isNotEmpty &&
          !_nombreCarpeta(carpeta).toLowerCase().contains(busqueda)) {
        libros = [
          for (final libro in libros)
            if (_nombre(libro).toLowerCase().contains(busqueda)) libro,
        ];
      }
      if (libros.isEmpty) continue;
      elementos.add(carpeta);
      if (busqueda.isNotEmpty || _desplegadas.contains(carpeta)) {
        elementos.addAll(libros);
      }
    }
    return elementos;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 720,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Abrir libro', style: tema.textTheme.titleLarge),
              const SizedBox(height: 12),
              _cabecera(tema),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrlBusqueda,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar libro o carpeta',
                  border: const OutlineInputBorder(),
                  suffixIcon: _ctrlBusqueda.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _ctrlBusqueda.clear()),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _lista(tema)),
              const SizedBox(height: 12),
              _pie(),
            ],
          ),
        ),
      ),
    );
  }

  /// Ruta de la carpeta principal y botones para actualizar y cambiarla.
  Widget _cabecera(ThemeData tema) {
    return Row(
      children: [
        Icon(Icons.folder_open, color: tema.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _carpeta.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _cargando ? null : _actualizar,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          onPressed: _cambiarCarpeta,
          icon: const Icon(Icons.drive_folder_upload),
          label: const Text('Cambiar carpeta…'),
        ),
      ],
    );
  }

  /// Totales, desplegar/plegar todo y Cancelar.
  Widget _pie() {
    return Row(
      children: [
        if (!_cargando) ...[
          Text('$_total libros en ${_carpetas.length} carpetas'),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _desplegarTodo(true),
            child: const Text('Desplegar todo'),
          ),
          TextButton(
            onPressed: () => _desplegarTodo(false),
            child: const Text('Plegar todo'),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  /// Lista de carpetas y libros (solo se dibuja lo que se ve).
  Widget _lista(ThemeData tema) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final elementos = _elementos();
    if (elementos.isEmpty) {
      final mensaje = !_carpeta.existsSync()
          ? 'La carpeta no existe'
          : (_total == 0
              ? 'No hay libros en esta carpeta ni en sus subcarpetas'
              : 'Ningún libro coincide con la búsqueda');
      return Center(child: Text(mensaje));
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: ListView.builder(
        itemCount: elementos.length,
        itemBuilder: (_, indice) {
          final elemento = elementos[indice];
          return elemento is File
              ? _libro(elemento)
              : _filaCarpeta(tema, elemento as String);
        },
      ),
    );
  }

  /// Fila de una carpeta: nombre, número de libros y flecha.
  Widget _filaCarpeta(ThemeData tema, String carpeta) {
    final buscando = _ctrlBusqueda.text.trim().isNotEmpty;
    final desplegada = buscando || _desplegadas.contains(carpeta);
    final cantidad = _grupos[carpeta]!.length;
    return ListTile(
      dense: true,
      tileColor: tema.colorScheme.surfaceContainerHighest,
      leading: Icon(
        desplegada ? Icons.folder_open : Icons.folder,
        color: Colors.amber.shade700,
      ),
      title: Text(
        _nombreCarpeta(carpeta),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cantidad == 1 ? '1 libro' : '$cantidad libros'),
          Icon(desplegada ? Icons.expand_less : Icons.expand_more),
        ],
      ),
      // Al buscar todas están desplegadas.
      onTap: buscando ? null : () => _alternar(carpeta),
    );
  }

  /// Fila de un libro (con sangría, dentro de su carpeta).
  Widget _libro(File libro) {
    final abierto = widget.libroActual != null &&
        p.equals(libro.path, widget.libroActual!);
    return ListTile(
      dense: true,
      selected: abierto,
      contentPadding: const EdgeInsets.only(left: 48, right: 16),
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(_nombre(libro)),
      trailing: abierto ? const Text('Abierto') : null,
      onTap: () => Navigator.pop(context, libro),
    );
  }
}
