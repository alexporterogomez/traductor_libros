// Aspecto y columnas comunes de las tablas (paquete trina_grid).

import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

/// Configuración común de las tablas: colores del tema, textos en
/// español, columnas que llenan el ancho y barra vertical visible.
TrinaGridConfiguration configuracionTabla(BuildContext context) {
  final tema = Theme.of(context);
  final colores = tema.colorScheme;
  final textoCelda = tema.textTheme.bodyMedium ?? const TextStyle();
  final textoTitulo = tema.textTheme.titleSmall ?? const TextStyle();

  return TrinaGridConfiguration(
    localeText: const TrinaGridLocaleText.spanish(),
    columnSize: const TrinaGridColumnSizeConfig(
      autoSizeMode: TrinaAutoSizeMode.scale,
      resizeMode: TrinaResizeMode.pushAndPull,
    ),
    scrollbar: const TrinaGridScrollbarConfig(isAlwaysShown: true),
    style: TrinaGridStyleConfig(
      // Tamaños.
      rowHeight: 34,
      columnHeight: 38,
      // Textos.
      cellTextStyle: textoCelda.copyWith(color: colores.onSurface),
      columnTextStyle: textoTitulo.copyWith(
        color: colores.onSurface,
        fontWeight: FontWeight.bold,
      ),
      // Fondo y filas alternas.
      gridBackgroundColor: colores.surface,
      rowColor: colores.surface,
      oddRowColor: colores.surface,
      evenRowColor: colores.surfaceContainerLow,
      // Fila y celda activas.
      activatedColor: colores.primaryContainer,
      activatedBorderColor: colores.primary,
      inactivatedBorderColor: colores.outline,
      unfocusedSelectionColor: colores.primaryContainer,
      cellColorInEditState: colores.surface,
      cellColorInReadOnlyState: colores.primaryContainer,
      // Bordes, iconos y menús.
      gridBorderColor: colores.outlineVariant,
      borderColor: colores.outlineVariant,
      iconColor: colores.onSurfaceVariant,
      menuBackgroundColor: colores.surface,
    ),
  );
}

/// Columna numérica alineada a la derecha. Los vacíos se ven en blanco.
/// [filtro]: la columna se puede filtrar en la fila de filtros.
TrinaColumn columnaNumero(
  String titulo,
  String campo, {
  double ancho = 80,
  bool filtro = false,
}) {
  return TrinaColumn(
    title: titulo,
    field: campo,
    // '#': sin separador de miles; los vacíos no se convierten en 0.
    type: TrinaColumnType.number(format: '#', applyFormatOnInit: false),
    formatter: (valor) => valor == null ? '' : '$valor',
    readOnly: true,
    width: ancho,
    minWidth: 45,
    suppressedAutoSize: true, // Mantiene su ancho.
    textAlign: TrinaColumnTextAlign.end,
    enableFilterMenuItem: filtro,
  );
}

/// Columna de texto. Si [editable], se edita con doble clic o Intro;
/// [validar] puede rechazar un valor devolviendo un mensaje.
/// [filtro]: la columna se puede filtrar en la fila de filtros.
TrinaColumn columnaTexto(
  String titulo,
  String campo, {
  double ancho = 120,
  bool fija = false,
  bool editable = false,
  bool filtro = false,
  String? Function(String valor)? validar,
}) {
  return TrinaColumn(
    title: titulo,
    field: campo,
    type: TrinaColumnType.text(),
    readOnly: !editable,
    width: ancho,
    minWidth: 50,
    suppressedAutoSize: fija,
    enableFilterMenuItem: filtro,
    validator: validar == null ? null : (valor, _) => validar('$valor'),
  );
}
