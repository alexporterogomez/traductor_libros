import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

import '../modelos/parrafo.dart';
import 'tabla_comun.dart';

/// Tabla de párrafos (trina_grid): ordenar, redimensionar columnas y
/// filtrar por columna. Al elegir una fila llama a [onSeleccionar].
class TablaParrafos extends StatefulWidget {
  const TablaParrafos({
    super.key,
    required this.parrafos,
    required this.idSeleccionado,
    required this.onSeleccionar,
    this.onCargada,
    this.onCambiarVista,
    this.mostrarCuento = false,
  });

  /// Añade la columna Cuento (libros de cuentos, con `id_cuento`).
  final bool mostrarCuento;

  /// Párrafos del libro. Si cambia el texto de alguno (corrección), se
  /// actualiza su fila sin crear la tabla de nuevo.
  final List<Parrafo> parrafos;

  /// Id del párrafo seleccionado, o null si no hay ninguno.
  final int? idSeleccionado;

  /// Se llama al elegir un párrafo. Si devuelve false (cambio cancelado),
  /// la tabla vuelve a marcar el seleccionado.
  final Future<bool> Function(Parrafo parrafo) onSeleccionar;

  /// Se llama cuando la tabla está lista, con su controlador (para saber
  /// qué filas quedan tras filtrar y ordenar).
  final ValueChanged<TrinaGridStateManager>? onCargada;

  /// Se llama cuando cambian las filas visibles (al filtrar u ordenar).
  final VoidCallback? onCambiarVista;

  @override
  State<TablaParrafos> createState() => _TablaParrafosState();
}

class _TablaParrafosState extends State<TablaParrafos> {
  /// Columnas de la tabla, en orden.
  late final List<TrinaColumn> _columnas = [
    columnaNumero('ID', 'id', ancho: 70, filtro: true),
    if (widget.mostrarCuento)
      columnaNumero('Cuento', 'id_cuento', ancho: 80, filtro: true),
    columnaNumero('Párrafo', 'parrafo', ancho: 85, filtro: true),
    columnaNumero('Bloque', 'bloque', ancho: 80, filtro: true),
    columnaTexto('Texto', 'texto', ancho: 400, filtro: true),
    columnaTexto('Fecha', 'fecha', ancho: 110, fija: true, filtro: true),
  ];

  /// Convierte un párrafo en una fila (guarda el párrafo en `data`).
  static TrinaRow _fila(Parrafo parrafo) => TrinaRow(
        data: parrafo,
        cells: {
          'id': TrinaCell(value: parrafo.id),
          'parrafo': TrinaCell(value: parrafo.parrafo),
          'bloque': TrinaCell(value: parrafo.bloque),
          'texto': TrinaCell(value: parrafo.original),
          'fecha': TrinaCell(value: parrafo.fecha ?? ''),
          'id_cuento': TrinaCell(value: parrafo.idCuento),
        },
      );

  /// Filas de la tabla, creadas una sola vez a partir de los párrafos.
  late final List<TrinaRow> _filas = [
    for (final parrafo in widget.parrafos) _fila(parrafo),
  ];

  /// Controlador de la tabla (disponible tras cargarse).
  TrinaGridStateManager? _tabla;

  /// Configuración visual; se crea una sola vez.
  TrinaGridConfiguration? _configuracion;

  @override
  void didUpdateWidget(covariant TablaParrafos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.parrafos, widget.parrafos)) _actualizarFilas();
    if (oldWidget.idSeleccionado != widget.idSeleccionado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _marcarSeleccionado());
    }
  }

  /// Tabla lista: muestra la fila de filtros y marca el seleccionado.
  void _alCargar(TrinaGridOnLoadedEvent evento) {
    developer.log('Tabla de párrafos cargada');
    _tabla = evento.stateManager;
    evento.stateManager.setShowColumnFilter(true); // Filtro por columna.
    evento.stateManager.addListener(_alNotificar);
    widget.onCargada?.call(evento.stateManager);
    _marcarSeleccionado();
  }

  /// Primera y última fila visibles y cuántas hay, para detectar cambios.
  (TrinaRow?, TrinaRow?, int)? _vista;

  /// Avisa si han cambiado las filas visibles (al filtrar u ordenar).
  void _alNotificar() {
    final filas = _tabla?.refRows;
    if (filas == null || !mounted) return;
    final vista = (
      filas.isEmpty ? null : filas.first,
      filas.isEmpty ? null : filas.last,
      filas.length,
    );
    if (vista == _vista) return;
    _vista = vista;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCambiarVista?.call();
    });
  }

  /// Actualiza el texto y la fecha de las filas que han cambiado sin crear la
  /// tabla de nuevo (así no se pierden los filtros ni el orden).
  void _actualizarFilas() {
    final porId = {for (final parrafo in widget.parrafos) parrafo.id: parrafo};
    for (final fila in _filas) {
      final nuevo = porId[(fila.data as Parrafo).id];
      if (nuevo == null || identical(nuevo, fila.data)) continue;
      fila.setData(nuevo);
      fila.cells['texto']!.value = nuevo.original;
      fila.cells['fecha']!.value = nuevo.fecha ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabla?.notifyListeners();
    });
  }

  /// Se llama cuando cambia la celda activa (clic o flechas del teclado).
  Future<void> _alCambiarCelda(TrinaGridOnActiveCellChangedEvent evento) async {
    final parrafo = _tabla?.currentRow?.data;
    if (parrafo is! Parrafo || parrafo.id == widget.idSeleccionado) return;

    final aceptado = await widget.onSeleccionar(parrafo);
    if (!aceptado && mounted) _marcarSeleccionado();
  }

  /// Marca la fila del párrafo seleccionado y la muestra.
  void _marcarSeleccionado() {
    final tabla = _tabla;
    if (tabla == null || !mounted) return;

    final indice = tabla.refRows.indexWhere(
      (fila) => (fila.data as Parrafo?)?.id == widget.idSeleccionado,
    );
    if (indice < 0) {
      // No está a la vista (lo oculta un filtro).
      tabla.clearCurrentCell(notify: false);
    } else if (tabla.currentRowIdx != indice) {
      tabla.moveCurrentCellByRowIdx(indice, TrinaMoveDirection.down);
    }
    tabla.notifyListeners();
  }

  /// Tras ordenar se vuelve a marcar el seleccionado.
  void _alOrdenar(TrinaGridOnSortedEvent evento) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _marcarSeleccionado());
  }

  /// Color de fila: seleccionada resaltada y el resto alternas.
  Color _colorFila(TrinaRowColorContext fila) {
    final colores = Theme.of(context).colorScheme;
    final parrafo = fila.row.data as Parrafo?;
    if (parrafo?.id == widget.idSeleccionado) return colores.primaryContainer;
    return fila.rowIdx.isOdd ? colores.surfaceContainerLow : colores.surface;
  }

  @override
  Widget build(BuildContext context) {
    return TrinaGrid(
      columns: _columnas,
      rows: _filas,
      mode: TrinaGridMode.readOnly,
      configuration: _configuracion ??= configuracionTabla(context),
      rowColorCallback: _colorFila,
      onLoaded: _alCargar,
      onActiveCellChanged: _alCambiarCelda,
      onSorted: _alOrdenar,
      noRowsWidget: const Center(child: Text('No hay párrafos')),
    );
  }
}
