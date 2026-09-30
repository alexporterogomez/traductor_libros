import 'package:flutter/material.dart';

import '../modelos/parrafo.dart';
import '../utilidades/idiomas.dart';
import 'controles_guardado.dart';

/// Editor del párrafo en el idioma elegido, con Traducir, Guardar y
/// Revertir. En el original, Traducir está deshabilitado.
class PanelDetalle extends StatelessWidget {
  const PanelDetalle({
    super.key,
    required this.parrafo,
    required this.idiomaDestino,
    required this.esOriginal,
    required this.controladorTraduccion,
    required this.hayCambios,
    required this.traduccionVacia,
    required this.traduciendo,
    required this.versionesAnteriores,
    required this.hayAnterior,
    required this.haySiguiente,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onTextoEditado,
    required this.onTraducir,
    required this.onGuardar,
    required this.onRevertir,
  });

  /// Párrafo que se edita, o null si no hay ninguno seleccionado.
  final Parrafo? parrafo;

  /// Idioma que se edita (traducción u original).
  final String idiomaDestino;

  /// El idioma que se edita es el original (no se puede traducir).
  final bool esOriginal;

  /// Controlador del cuadro de traducción (lo gestiona la pantalla).
  final TextEditingController controladorTraduccion;

  /// El cuadro de traducción tiene cambios sin guardar.
  final bool hayCambios;

  /// No hay traducción guardada: el botón dice "Traducir".
  final bool traduccionVacia;

  /// Hay una traducción de la IA en curso: se bloquean edición y botones.
  final bool traduciendo;

  /// Número de versiones anteriores guardadas en el historial.
  final int versionesAnteriores;

  /// Existe un párrafo anterior / siguiente (habilitan las flechas).
  final bool hayAnterior;
  final bool haySiguiente;

  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  /// Se llama cada vez que el usuario modifica el cuadro de traducción.
  final VoidCallback onTextoEditado;

  final VoidCallback onTraducir;
  final VoidCallback onGuardar;
  final VoidCallback onRevertir;

  @override
  Widget build(BuildContext context) {
    final seleccionado = parrafo;
    if (seleccionado == null) {
      return const Center(child: Text('Selecciona un párrafo de la tabla.'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(context, seleccionado),
          const SizedBox(height: 8),
          Text(
            esOriginal
                ? 'Texto original · ${nombreIdioma(idiomaDestino)}'
                : 'Traducción · ${nombreIdioma(idiomaDestino)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(child: _campoTraduccion(context)),
          const SizedBox(height: 8),
          _botones(),
        ],
      ),
    );
  }

  /// Flechas y datos del párrafo.
  Widget _cabecera(BuildContext context, Parrafo seleccionado) {
    final negrita = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(fontWeight: FontWeight.bold);

    return Row(
      children: [
        IconButton(
          tooltip: 'Párrafo anterior (Ctrl + ↑)',
          onPressed: hayAnterior ? onAnterior : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Párrafo siguiente (Ctrl + ↓)',
          onPressed: haySiguiente ? onSiguiente : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('id: ${seleccionado.id}', style: negrita),
              Text('párrafo: ${seleccionado.parrafo ?? '-'}', style: negrita),
              if (seleccionado.idCuento != null)
                Text('cuento: ${seleccionado.idCuento}', style: negrita),
              if (seleccionado.bloque != null)
                Text('bloque: ${seleccionado.bloque}', style: negrita),
              Text('${seleccionado.caracteres} caracteres'),
            ],
          ),
        ),
      ],
    );
  }

  /// Estilo del texto de la traducción.
  TextStyle? _estiloTexto(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4);

  /// Cuadro de texto: borde naranja si hay cambios; bloqueado al traducir.
  Widget _campoTraduccion(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final bordeCambios = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
    );

    return TextField(
      controller: controladorTraduccion,
      readOnly: traduciendo,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: _estiloTexto(context),
      onChanged: (_) => onTextoEditado(),
      decoration: InputDecoration(
        filled: true,
        fillColor: colores.surface,
        contentPadding: const EdgeInsets.all(12),
        border: const OutlineInputBorder(),
        enabledBorder: hayCambios
            ? bordeCambios
            : OutlineInputBorder(borderSide: BorderSide(color: colores.outline)),
        focusedBorder: hayCambios ? bordeCambios : null,
      ),
    );
  }

  /// Botones Traducir / Guardar / Revertir y texto de estado.
  Widget _botones() {
    final puedeTrabajar = !traduciendo;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: puedeTrabajar && !esOriginal ? onTraducir : null,
          icon: const Icon(Icons.translate),
          label: Text(traduccionVacia ? 'Traducir' : 'Retraducir'),
        ),
        Tooltip(
          message: 'Guardar (Ctrl + S)',
          child: OutlinedButton.icon(
            onPressed: puedeTrabajar && hayCambios ? onGuardar : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ),
        BotonRevertir(
          hayCambios: hayCambios,
          versiones: versionesAnteriores,
          habilitado: puedeTrabajar,
          onRevertir: onRevertir,
        ),
        if (traduciendo)
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Traduciendo…'),
            ],
          )
        else
          EstadoGuardado(
            hayCambios: hayCambios,
            versiones: versionesAnteriores,
          ),
      ],
    );
  }
}
