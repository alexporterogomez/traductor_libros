import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pantallas/pantalla_principal.dart';


//// Punto de entrada. En escritorio SQLite se usa por FFI, por eso se
/// inicializa antes de arrancar.
void main() {
  sqfliteFfiInit();
  runApp(const TraductorLibrosApp());
}

/// Widget raíz: define el tema visual y abre la [PantallaPrincipal].
class TraductorLibrosApp extends StatelessWidget {
  const TraductorLibrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traductor de libros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8D5A2B),
        scaffoldBackgroundColor: const Color(0xFFFFF4E5),
      ),
      home: const PantallaPrincipal(),
    );
  }
}
