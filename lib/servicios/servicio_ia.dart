import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../modelos/palabra.dart';
import '../utilidades/idiomas.dart';
import 'prompt_lemas.dart';

/// Error de traducción con un mensaje apto para mostrar al usuario.
class ErrorIA implements Exception {
  ErrorIA(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Cliente del servidor de IA (llama.cpp, API tipo OpenAI) que traduce
/// párrafos.
class ServicioIA {
  ServicioIA({String tipo = 'llama.cpp:2'}) {
    configurar(tipo);
  }

  /// Servidores del menú (`llama.cpp:1` existe pero no se ofrece).
  static const List<String> tipos = ['llama.cpp:2'];

  /// Tiempo máximo de espera por traducción (los modelos locales son lentos).
  static const Duration tiempoMaximo = Duration(minutes: 3);

  /// Servidor seleccionado.
  late String tipo;

  /// Dirección completa del endpoint de chat.
  late Uri url;

  /// Modelo que se pide al servidor.
  late String modelo;

  /// `host:puerto` del servidor, para los mensajes de error.
  String get direccion => '${url.host}:${url.port}';

  /// Selecciona el servidor [nuevoTipo] y su modelo.
  void configurar(String nuevoTipo) {
    if (nuevoTipo == 'llama.cpp:1') {
      url = Uri.parse('http://localhost:11435/v1/chat/completions');
      modelo = 'gemma-4-E4B-it-Q4_0.gguf';
    } else if (nuevoTipo == 'llama.cpp:2') {
      url = Uri.parse('http://192.168.0.22:11434/v1/chat/completions');
      modelo = 'gemma-4-E4B-it-Q4_0.gguf';
    } else {
      throw ArgumentError('Servidor desconocido: $nuevoTipo');
    }
    tipo = nuevoTipo;
  }

  /// Instrucciones para el modelo, en inglés (las sigue mejor).
  static String instrucciones(String idiomaOrigen, String idiomaDestino) {
    final origen = nombreIdiomaEnIngles(idiomaOrigen);
    final destino = nombreIdiomaEnIngles(idiomaDestino);
    return 'You are a professional literary translator.\n'
        'Translate the text sent by the user from $origen into $destino.\n'
        'Rules:\n'
        '- Translate faithfully and completely, keeping the meaning, tone and '
        'literary style.\n'
        '- Keep the same paragraph structure. Do not summarize or leave '
        'anything out.\n'
        '- Use the punctuation and quotation marks that are correct in '
        '$destino.\n'
        '- Reply ONLY with the translation: no explanations, notes, titles or '
        'quotes around it.';
  }

  /// Traduce [texto] entre dos idiomas (`en`, `es`...). Lanza [ErrorIA] si
  /// falla la conexión o la respuesta.
  Future<String> traducir({
    required String texto,
    required String idiomaOrigen,
    required String idiomaDestino,
  }) async {
    if (texto.trim().isEmpty) {
      throw ErrorIA('El texto original de este párrafo está vacío.');
    }

    final traduccion = await _preguntar(
      [
        {'role': 'system', 'content': instrucciones(idiomaOrigen, idiomaDestino)},
        {'role': 'user', 'content': texto},
      ],
      maxTokens: 2048,
    );
    if (traduccion.isEmpty) {
      throw ErrorIA('La IA ha devuelto una traducción vacía.');
    }
    return traduccion;
  }

  /// Pide a la IA el lema y el tipo de cada una de las [palabras] del
  /// párrafo [texto] (en el idioma [idioma]). Devuelve las mismas palabras,
  /// en las mismas posiciones, con el lema y el tipo nuevos.
  Future<List<Palabra>> lematizar({
    required String texto,
    required String idioma,
    required List<Palabra> palabras,
  }) async {
    if (palabras.isEmpty) {
      throw ErrorIA('Este párrafo no tiene palabras.');
    }
    final mapa = jsonEncode({for (final p in palabras) '${p.indice}': p.palabra});
    final respuesta = await _preguntar(
      [
        {'role': 'user', 'content': getPromptLemmas(idioma, texto, mapa)},
      ],
      maxTokens: 8192, // La respuesta tiene una línea por palabra.
    );

    final nuevas = {for (final p in Palabra.desdeKeys(respuesta)) p.indice: p};
    if (nuevas.isEmpty) {
      throw ErrorIA('La IA no ha devuelto un JSON de palabras válido:\n'
          '${_recortar(respuesta)}');
    }
    // Se conserva la palabra original; de la IA solo se toman lema y tipo.
    return [
      for (final p in palabras)
        if (nuevas[p.indice] case final nueva?)
          p.copyWith(lema: nueva.lema, tipo: nueva.tipo)
        else
          p,
    ];
  }

  /// Envía [mensajes] al servidor y devuelve la respuesta de la IA, ya
  /// limpia. Lanza [ErrorIA] si el servidor responde con error.
  Future<String> _preguntar(
    List<Map<String, String>> mensajes, {
    required int maxTokens,
  }) async {
    final respuesta = await _enviar(jsonEncode({
      'model': modelo,
      'messages': mensajes,
      'temperature': 0.2, // Poca creatividad: respuestas fieles.
      'max_tokens': maxTokens,
      'stream': false,
    }));

    // UTF-8 explícito para no estropear tildes u otros alfabetos.
    final cuerpo = utf8.decode(respuesta.bodyBytes, allowMalformed: true);
    if (respuesta.statusCode != 200) {
      throw ErrorIA('El servidor $direccion respondió con el error '
          '${respuesta.statusCode}:\n${_recortar(cuerpo)}');
    }
    return limpiarRespuesta(_extraerContenido(cuerpo));
  }

  /// Envía la petición y convierte los errores de red en [ErrorIA].
  Future<http.Response> _enviar(String cuerpo) async {
    try {
      return await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: utf8.encode(cuerpo),
          )
          .timeout(tiempoMaximo);
    } on TimeoutException {
      throw ErrorIA('El servidor $direccion no ha respondido en '
          '${tiempoMaximo.inMinutes} minutos.');
    } on SocketException catch (e) {
      throw ErrorIA(_sinConexion(e.message));
    } on http.ClientException catch (e) {
      throw ErrorIA(_sinConexion(e.message));
    }
  }

  /// Mensaje de error de conexión con las comprobaciones habituales.
  String _sinConexion(String detalle) =>
      'No se pudo conectar con el servidor de IA ($tipo → $direccion).\n\n'
      '• Comprueba que llama.cpp está arrancado en ese equipo.\n'
      '• Debe escuchar en la red: --host 0.0.0.0 --port ${url.port}\n'
      '• El cortafuegos de ese equipo debe permitir el puerto ${url.port}.\n\n'
      'Detalle: $detalle';

  /// Saca el texto de `choices[0].message.content`.
  static String _extraerContenido(String json) {
    try {
      final datos = jsonDecode(json);
      return (datos['choices'][0]['message']['content'] ?? '').toString();
    } catch (_) {
      throw ErrorIA('Respuesta inesperada del servidor:\n${_recortar(json)}');
    }
  }

  /// Quita de la respuesta los bloques `<think>` y ``` que añaden algunos
  /// modelos.
  static String limpiarRespuesta(String texto) {
    var limpio =
        texto.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    if (limpio.length >= 6 &&
        limpio.startsWith('```') &&
        limpio.endsWith('```')) {
      limpio = limpio.substring(3, limpio.length - 3);
      // Si la primera línea es solo una etiqueta (```text), se elimina.
      final salto = limpio.indexOf('\n');
      if (salto >= 0 && !limpio.substring(0, salto).trim().contains(' ')) {
        limpio = limpio.substring(salto + 1);
      }
      limpio = limpio.trim();
    }
    return limpio;
  }

  /// Limita [texto] a 500 caracteres para los mensajes de error.
  static String _recortar(String texto) =>
      texto.length <= 500 ? texto : '${texto.substring(0, 500)}…';
}
