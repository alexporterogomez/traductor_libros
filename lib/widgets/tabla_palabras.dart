import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

import '../modelos/palabra.dart';
import 'controles_guardado.dart';
import 'tabla_comun.dart';

/// Tabla editable de las palabras del párrafo (columna `keys`), con sus
/// propios botones Guardar y Revertir. Los cambios se confirman con Intro.
class TablaPalabras extends StatefulWidget {
  const TablaPalabras({
    super.key,
    required this.revision,
    required this.palabras,
    required this.hayCambios,
    required this.versionesAnteriores,
    required this.generando,
    required this.mensajeVacio,
    required this.onEditar,
    required this.onGuardar,
    required this.onRevertir,
    required this.onGenerar,
  });

  /// Cambia cuando las palabras se cargan de nuevo; entonces la tabla se
  /// crea otra vez.
  final int revision;

  /// Palabras a mostrar, incluidas las ediciones aún no guardadas.
  final List<Palabra> palabras;

  /// Hay ediciones sin guardar (habilita Guardar).
  final bool hayCambios;

  /// Número de versiones anteriores guardadas en el historial.
  final int versionesAnteriores;

  /// Texto que se muestra cuando no hay palabras.
  final String mensajeVacio;

  /// Se llama al confirmar la edición de una celda.
  final ValueChanged<Palabra> onEditar;

  final VoidCallback onGuardar;
  final VoidCallback onRevertir;

  /// La IA está generando los lemas (se muestra "Generando…").
  final bool generando;

  /// Pide a la IA de nuevo los lemas y tipos del párrafo.
  final VoidCallback onGenerar;

  @override
  State<TablaPalabras> createState() => _TablaPalabrasState();
}

class _TablaPalabrasState extends State<TablaPalabras> {
  /// Columnas y filas; se crean de nuevo al cambiar la revisión.
  late List<TrinaColumn> _columnas = _crearColumnas();
  late List<TrinaRow> _filas = _crearFilas();

  /// Configuración visual; se crea una sola vez.
  TrinaGridConfiguration? _configuracion;

  /// Columnas de la tabla, en orden.
  static List<TrinaColumn> _crearColumnas() => [
        columnaNumero('ID', 'indice', ancho: 50),
        columnaTexto('Palabra', 'palabra', editable: true, validar: _validar),
        columnaTexto('Lema', 'lema', editable: true, validar: _validar),
        columnaTexto('Tipo', 'tipo',
            ancho: 80, editable: true, validar: _validar),
      ];

  List<TrinaRow> _crearFilas() =>
      [for (final palabra in widget.palabras) _fila(palabra)];

  /// Convierte una palabra en una fila.
  static TrinaRow _fila(Palabra palabra) => TrinaRow(
        cells: {
          'indice': TrinaCell(value: palabra.indice),
          'palabra': TrinaCell(value: palabra.palabra),
          'lema': TrinaCell(value: palabra.lema),
          'tipo': TrinaCell(value: palabra.tipo),
        },
      );

  /// Rechaza "|" (separa palabra, lema y tipo en `keys`).
  static String? _validar(String valor) => valor.contains('|')
      ? 'No se puede usar el carácter "|": separa palabra, lema y tipo.'
      : null;

  @override
  void didUpdateWidget(covariant TablaPalabras oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _columnas = _crearColumnas();
      _filas = _crearFilas();
    }
  }

  /// Al confirmar una celda, avisa con la palabra de esa fila.
  void _alEditar(TrinaGridOnChangedEvent evento) {
    // Se ignoran ediciones de una tabla ya sustituida.
    if (!_filas.contains(evento.row)) return;

    final celdas = evento.row.cells;
    final palabra = Palabra(
      (celdas['indice']!.value as num).toInt(),
      '${celdas['palabra']!.value}',
      '${celdas['lema']!.value}',
      '${celdas['tipo']!.value}',
    );
    // Se avisa justo después: trina_grid puede confirmar la edición en un
    // momento en que no se puede actualizar la pantalla.
    Future.microtask(() {
      if (mounted) widget.onEditar(palabra);
    });
  }

  /// Muestra el motivo por el que se ha rechazado un valor.
  void _alRechazar(TrinaGridValidationEvent evento) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(evento.errorMessage)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TrinaGrid(
            // Tabla nueva con cada revisión.
            key: ValueKey(widget.revision),
            columns: _columnas,
            rows: _filas,
            configuration: _configuracion ??= configuracionTabla(context),
            onChanged: _alEditar,
            onValidationFailed: _alRechazar,
            noRowsWidget: Center(child: Text(widget.mensajeVacio)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: 'Volver a generar lemas y tipos con la IA',
              child: FilledButton.icon(
                onPressed: widget.palabras.isEmpty || widget.generando
                    ? null
                    : widget.onGenerar,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar con IA'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.hayCambios ? widget.onGuardar : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
            BotonRevertir(
              hayCambios: widget.hayCambios,
              versiones: widget.versionesAnteriores,
              onRevertir: widget.onRevertir,
            ),
            if (widget.generando)
              const Text('Generando…')
            else
              EstadoGuardado(
                hayCambios: widget.hayCambios,
                versiones: widget.versionesAnteriores,
              ),
          ],
        ),
      ],
    );
  }
}
