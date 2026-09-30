import 'package:flutter/material.dart';

/// Botón Revertir: descarta los cambios sin guardar o vuelve a la
/// versión anterior.
class BotonRevertir extends StatelessWidget {
  const BotonRevertir({
    super.key,
    required this.hayCambios,
    required this.versiones,
    required this.onRevertir,
    this.habilitado = true,
  });

  /// Hay cambios sin guardar.
  final bool hayCambios;

  /// Número de versiones anteriores guardadas en el historial.
  final int versiones;

  final VoidCallback onRevertir;

  /// Deshabilita el botón por otros motivos (p. ej. traduciendo).
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final activo = habilitado && (hayCambios || versiones > 0);
    return Tooltip(
      message: hayCambios
          ? 'Descartar los cambios sin guardar'
          : 'Volver a la versión guardada anterior',
      child: OutlinedButton.icon(
        onPressed: activo ? onRevertir : null,
        icon: const Icon(Icons.undo),
        label: const Text('Revertir'),
      ),
    );
  }
}

/// Texto junto a Guardar/Revertir: "Cambios sin guardar" o el número de
/// versiones anteriores.
class EstadoGuardado extends StatelessWidget {
  const EstadoGuardado({
    super.key,
    required this.hayCambios,
    required this.versiones,
  });

  /// Hay cambios sin guardar.
  final bool hayCambios;

  /// Número de versiones anteriores guardadas en el historial.
  final int versiones;

  @override
  Widget build(BuildContext context) {
    if (hayCambios) {
      return Text(
        'Cambios sin guardar',
        style: TextStyle(
          color: Colors.orange.shade800,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    if (versiones > 0) {
      return Text(
        versiones == 1 ? '1 versión anterior' : '$versiones versiones anteriores',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return const SizedBox.shrink();
  }
}
