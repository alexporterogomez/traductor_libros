import 'package:flutter/material.dart';

/// Línea que se arrastra para repartir el espacio entre dos zonas.
class Divisor extends StatelessWidget {
  const Divisor({
    super.key,
    required this.vertical,
    required this.onArrastrar,
    required this.onSoltar,
  });

  /// Grosor de la zona sensible al ratón (la línea visible mide 1 px).
  static const double grosor = 9;

  /// true: línea vertical (se arrastra en horizontal); false: horizontal.
  final bool vertical;

  /// Se llama durante el arrastre con los píxeles desplazados.
  final ValueChanged<double> onArrastrar;

  /// Se llama al soltar el ratón (por ejemplo, para guardar la posición).
  final VoidCallback onSoltar;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return MouseRegion(
      cursor: vertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate:
            vertical ? (detalles) => onArrastrar(detalles.delta.dx) : null,
        onHorizontalDragEnd: vertical ? (_) => onSoltar() : null,
        onVerticalDragUpdate:
            vertical ? null : (detalles) => onArrastrar(detalles.delta.dy),
        onVerticalDragEnd: vertical ? null : (_) => onSoltar(),
        child: vertical
            ? VerticalDivider(width: grosor, thickness: 1, color: color)
            : Divider(height: grosor, thickness: 1, color: color),
      ),
    );
  }
}
