import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../modelos/parrafo.dart';
import '../utilidades/dialogos.dart';
import '../utilidades/reemplazo.dart';

/// Diálogo para corregir una palabra del texto original (p. ej.
/// "to-day" → "today").
///
/// Recorre los párrafos que la contienen y, en cada uno, muestra el texto
/// actual y el corregido para decidir si se corrige o se omite. Guarda y
/// deshace mediante [onCorregir] y [onDeshacer].
class DialogoCorregir extends StatefulWidget {
  const DialogoCorregir({
    super.key,
    required this.parrafos,
    required this.nombreIdioma,
    required this.idInicial,
    required this.onCorregir,
    required this.onDeshacer,
  });

  /// Todos los párrafos del libro, ordenados por id.
  final List<Parrafo> parrafos;

  /// Nombre del idioma original, para el título.
  final String nombreIdioma;

  /// Párrafo por el que empezar si contiene la palabra.
  final int? idInicial;

  /// Guarda el texto corregido y devuelve el párrafo actualizado.
  final Future<Parrafo> Function(Parrafo parrafo, String textoNuevo)
      onCorregir;

  /// Deshace la última corrección y devuelve el párrafo, o null.
  final Future<Parrafo?> Function(Parrafo parrafo) onDeshacer;

  @override
  State<DialogoCorregir> createState() => _DialogoCorregirState();
}

class _DialogoCorregirState extends State<DialogoCorregir> {
  final TextEditingController _ctrlBuscar = TextEditingController();
  final TextEditingController _ctrlCorreccion = TextEditingController();

  /// Copia de los párrafos, actualizada con cada corrección.
  late List<Parrafo> _parrafos = widget.parrafos;

  /// Párrafos que contienen la palabra buscada.
  List<Parrafo> _coincidencias = [];

  /// Posición en [_coincidencias] del párrafo que se está revisando.
  int _indice = 0;

  /// Párrafos corregidos en esta sesión, en orden, para poder deshacer.
  final List<Parrafo> _corregidos = [];

  /// Hay un guardado en curso (se bloquean los botones).
  bool _guardando = false;

  /// Búsqueda y sustitución con los valores actuales del diálogo (solo
  /// palabras completas y sin distinguir mayúsculas).
  Reemplazo get _reemplazo => Reemplazo(
        buscar: _ctrlBuscar.text.trim(),
        reemplazo: _ctrlCorreccion.text.trim(),
      );

  /// Párrafo que se está revisando, o null si no hay coincidencias.
  Parrafo? get _actual =>
      _coincidencias.isEmpty ? null : _coincidencias[_indice];

  /// Hay párrafo, corrección distinta y ningún guardado en curso.
  bool get _puedeCorregir =>
      _actual != null &&
      !_guardando &&
      _ctrlCorreccion.text.trim().isNotEmpty &&
      _ctrlCorreccion.text.trim() != _ctrlBuscar.text.trim();

  @override
  void dispose() {
    _ctrlBuscar.dispose();
    _ctrlCorreccion.dispose();
    super.dispose();
  }

  /// Recalcula los párrafos que contienen la palabra y se coloca en
  /// [preferido] si está entre ellos; si no, en el primero.
  void _buscar({int? preferido}) {
    final reemplazo = _reemplazo;
    _coincidencias = [
      for (final parrafo in _parrafos)
        if (reemplazo.contar(parrafo.original) > 0) parrafo,
    ];
    final posicion = _coincidencias.indexWhere((p) => p.id == preferido);
    _indice = math.max(0, posicion);
  }

  /// Sustituye un párrafo de la copia local por su versión actualizada.
  void _actualizarParrafo(Parrafo nuevo) {
    _parrafos = [
      for (final parrafo in _parrafos) parrafo.id == nuevo.id ? nuevo : parrafo,
    ];
  }

  /// Corrige el párrafo actual y pasa al siguiente que contenga la palabra.
  Future<void> _corregir() async {
    final parrafo = _actual;
    if (parrafo == null || !_puedeCorregir) return;

    // Si el texto no cambia, se pasa al siguiente sin guardar.
    final texto = _reemplazo.aplicar(parrafo.original);
    if (texto == parrafo.original) {
      _mover(1);
      return;
    }

    setState(() => _guardando = true);
    try {
      final nuevo = await widget.onCorregir(parrafo, texto);
      if (!mounted) return;
      setState(() {
        _actualizarParrafo(nuevo);
        _corregidos.add(nuevo);
        _buscar();
        // Siguiente párrafo con la palabra, detrás del corregido.
        final siguiente = _coincidencias.indexWhere((p) => p.id > nuevo.id);
        _indice = siguiente >= 0
            ? siguiente
            : math.max(0, _coincidencias.length - 1);
      });
    } catch (e) {
      if (mounted) {
        mostrarError(context,
            'No se pudo corregir el párrafo ${parrafo.id}.\n\n${explicarError(e)}');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Deshace la última corrección y vuelve a ese párrafo.
  Future<void> _deshacer() async {
    if (_corregidos.isEmpty || _guardando) return;
    final ultimo = _corregidos.last;

    setState(() => _guardando = true);
    try {
      final restaurado = await widget.onDeshacer(ultimo);
      if (!mounted) return;
      setState(() {
        _corregidos.removeLast();
        if (restaurado != null) _actualizarParrafo(restaurado);
        _buscar(preferido: ultimo.id);
      });
    } catch (e) {
      if (mounted) {
        mostrarError(context,
            'No se pudo deshacer la corrección.\n\n${explicarError(e)}');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Pasa al párrafo anterior (-1) o al siguiente (+1) sin corregir.
  void _mover(int salto) {
    final nuevo = _indice + salto;
    if (nuevo < 0 || nuevo >= _coincidencias.length) return;
    setState(() => _indice = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tamano = MediaQuery.sizeOf(context);

    return Dialog(
      child: SizedBox(
        width: math.min(1100, math.max(480, tamano.width - 80)),
        height: math.min(720, math.max(420, tamano.height - 80)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Corregir palabra en el texto original (${widget.nombreIdioma})',
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _campos(),
              const SizedBox(height: 12),
              _navegacion(tema),
              const SizedBox(height: 8),
              Expanded(child: _vistas(tema)),
              const SizedBox(height: 16),
              _botones(),
            ],
          ),
        ),
      ),
    );
  }

  /// Cuadros de la palabra a corregir y de su corrección.
  Widget _campos() {
    InputDecoration decoracion(String etiqueta, IconData icono) =>
        InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          border: const OutlineInputBorder(),
          isDense: true,
        );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrlBuscar,
            autofocus: true,
            decoration: decoracion('Palabra a corregir', Icons.search),
            // Empieza en el párrafo seleccionado si contiene la palabra.
            onChanged: (_) =>
                setState(() => _buscar(preferido: widget.idInicial)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward),
        ),
        Expanded(
          child: TextField(
            controller: _ctrlCorreccion,
            decoration: decoracion('Corrección', Icons.edit_outlined),
            // La vista del texto corregido se actualiza al escribir.
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  /// Posición en las coincidencias y flechas para moverse entre ellas.
  Widget _navegacion(ThemeData tema) {
    final actual = _actual;
    final String texto;
    if (_ctrlBuscar.text.trim().isEmpty) {
      texto = 'Escribe la palabra que quieres corregir.';
    } else if (actual == null) {
      texto = 'Ningún párrafo contiene «${_ctrlBuscar.text.trim()}».';
    } else {
      final veces = _reemplazo.contar(actual.original);
      texto = 'Párrafo ${_indice + 1} de ${_coincidencias.length}'
          '  ·  id ${actual.id}'
          '  ·  ${veces == 1 ? '1 vez' : '$veces veces'} en este párrafo';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: tema.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Párrafo anterior',
          onPressed: _indice > 0 ? () => _mover(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Párrafo siguiente',
          onPressed:
              _indice < _coincidencias.length - 1 ? () => _mover(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// Texto actual y texto corregido, lado a lado.
  Widget _vistas(ThemeData tema) {
    final actual = _actual;
    if (actual == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: tema.colorScheme.outlineVariant),
        ),
        child: const SizedBox.expand(),
      );
    }

    final reemplazo = _reemplazo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _vista(
            tema,
            titulo: 'Texto actual',
            parrafo: actual,
            tramos: reemplazo.tramos(actual.original, sustituir: false),
            resaltado: Colors.amber.shade200,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _vista(
            tema,
            titulo: 'Texto corregido',
            parrafo: actual,
            tramos: _ctrlCorreccion.text.trim().isEmpty
                ? reemplazo.tramos(actual.original, sustituir: false)
                : reemplazo.tramos(actual.original, sustituir: true),
            resaltado: Colors.lightGreen.shade200,
          ),
        ),
      ],
    );
  }

  /// Recuadro con el texto y la palabra resaltada.
  Widget _vista(
    ThemeData tema, {
    required String titulo,
    required Parrafo parrafo,
    required List<(String, bool)> tramos,
    required Color resaltado,
  }) {
    final estilo = tema.textTheme.bodyLarge?.copyWith(height: 1.5);
    final estiloResaltado = estilo?.copyWith(
      backgroundColor: resaltado,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo,
          style: tema.textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: tema.colorScheme.surface,
              border: Border.all(color: tema.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              // Desplazamiento al principio al cambiar de párrafo.
              key: ValueKey(parrafo.id),
              padding: const EdgeInsets.all(12),
              child: SelectableText.rich(
                TextSpan(
                  style: estilo,
                  children: [
                    for (final (texto, esPalabra) in tramos)
                      TextSpan(
                        text: texto,
                        style: esPalabra ? estiloResaltado : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Botones de la parte inferior.
  Widget _botones() {
    final hayActual = _actual != null && !_guardando;
    return Row(
      children: [
        TextButton.icon(
          onPressed:
              _corregidos.isEmpty || _guardando ? null : _deshacer,
          icon: const Icon(Icons.undo),
          label: Text(_corregidos.isEmpty
              ? 'Deshacer'
              : 'Deshacer (${_corregidos.length} corregidos)'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: hayActual && _indice < _coincidencias.length - 1
              ? () => _mover(1)
              : null,
          icon: const Icon(Icons.skip_next),
          label: const Text('Omitir'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _puedeCorregir ? _corregir : null,
          icon: const Icon(Icons.check),
          label: const Text('Corregir este párrafo'),
        ),
      ],
    );
  }
}
