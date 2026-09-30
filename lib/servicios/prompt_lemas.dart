/// Instrucciones (prompt) para que la IA genere las palabras de un párrafo
/// con su lema y su tipo, en el formato de la columna `keys`:
/// `{"0":"Los|el|det", ...}`.
///
/// [idioma] es el código del idioma (`es`, `en`...), [texto] el párrafo
/// original y [lemasMapStr] las palabras numeradas (`{"0":"Los", ...}`).
String getPromptLemmas(String idioma, String texto, String lemasMapStr) {
  // Mapa de ejemplos por idioma (solo se usará el que corresponda, pero
  // tenerlos todos dentro del prompt evita confusiones entre idiomas).
  const ejemplos = {
    "es": {
      "texto": "Los niños juegan en el parque.",
      "map": '{"0":"Los","1":"niños","2":"juegan","3":"en","4":"el","5":"parque"}',
      "respuesta": '{"0":"Los|el|det","1":"niños|niño|noun","2":"juegan|jugar|verb","3":"en|en|adp","4":"el|el|det","5":"parque|parque|noun"}',
    },
    "en": {
      "texto": "It's a lovely day. I'm twenty and my dog's name is Rex.",
      "map": '{"0":"It\'s","1":"a","2":"lovely","3":"day","4":"I\'m","5":"twenty","6":"and","7":"my","8":"dog\'s","9":"name","10":"is","11":"Rex"}',
      "respuesta": '{"0":"It\'s|be|verb","1":"a|a|det","2":"lovely|lovely|adj","3":"day|day|noun","4":"I\'m|I;be|verb","5":"twenty|twenty|num","6":"and|and|conj","7":"my|my|det","8":"dog\'s|dog|noun","9":"name|name|noun","10":"is|be|verb","11":"Rex|Rex|propn"}',
    },
    "de": {
      "texto": "Die Kinder spielen im Park.",
      "map": '{"0":"Die","1":"Kinder","2":"spielen","3":"im","4":"Park"}',
      "respuesta": '{"0":"Die|der|det","1":"Kinder|Kind|noun","2":"spielen|spielen|verb","3":"im|in|adp","4":"Park|Park|noun"}',
    },
    "fr": {
      "texto": "Les enfants jouent dans le parc. L'homme a vingt ans et j'ai faim.",
      "map": '{"0":"Les","1":"enfants","2":"jouent","3":"dans","4":"le","5":"parc","6":"L\'homme","7":"a","8":"vingt","9":"ans","10":"j\'ai","11":"faim"}',
      "respuesta": '{"0":"Les|le|det","1":"enfants|enfant|noun","2":"jouent|jouer|verb","3":"dans|dans|adp","4":"le|le|det","5":"parc|parc|noun","6":"L\'homme|homme|noun","7":"a|avoir|verb","8":"vingt|vingt|num","9":"ans|an|noun","10":"j\'ai|je;avoir|verb","11":"faim|faim|noun"}',
    },
    "it": {
      "texto": "I bambini giocano nel parco. Ha ottant'anni e l'amico c'è.",
      "map": '{"0":"I","1":"bambini","2":"giocano","3":"nel","4":"parco","5":"Ha","6":"ottant\'anni","7":"e","8":"l\'amico","9":"c\'è"}',
      "respuesta": '{"0":"I|il|det","1":"bambini|bambino|noun","2":"giocano|giocare|verb","3":"nel|in|adp","4":"parco|parco|noun","5":"Ha|avere|verb","6":"ottant\'anni|ottanta;anno|num;noum","7":"e|e|conj","8":"l\'amico|amico|noun","9":"c\'è|essere|verb"}',
    },
    "ru": {"texto": "Дети играют в парке.", "map": '{"0":"Дети","1":"играют","2":"в","3":"парке"}', "respuesta": '{"0":"Дети|ребёнок|noun","1":"играют|играть|verb","2":"в|в|adp","3":"парке|парк|noun"}'},
    "pt": {
      "texto": "As crianças brincam no parque.",
      "map": '{"0":"As","1":"crianças","2":"brincam","3":"no","4":"parque"}',
      "respuesta": '{"0":"As|o|det","1":"crianças|criança|noun","2":"brincam|brincar|verb","3":"no|em|adp","4":"parque|parque|noun"}',
    },
  };

  final ejemplo = ejemplos[idioma] ?? ejemplos["es"]!;

  return """
    Actúa como un experto lingüista y procesador de lenguaje natural experto en '$idioma'. Tu tarea es lematizar la lista de palabras proporcionada. El texto original es solo contexto para desambiguar.
═══ REGLAS ═══
1. ANALISIS MORFOSINTACTICO: Para cada palabra, debes determinar primero su categoría gramatical (POS) en el contexto específico de la oración. 
Esto es crucial para palabras polisémicas (ej: "cura" puede ser sustantivo [sacerdote] o verbo [curar]; "vino" puede ser sustantivo [bebida] o verbo [venir]).
2. ORDEN Y EXACTITUD: Conserva el orden original y NO omitas ni añadas palabras. Procesa cada ID del JSON de entrada de manera secuencial y aislada.
3. FORMATO JSON: Devuelve ÚNICAMENTE un objeto JSON donde las claves son índices numéricos (0, 1, 2...) y los valores son strings en formato "palabra_original|lema|categoria".
   · palabra_original: copia LITERAL del token recibido, sin cambiar ni una letra.
   · lema: UNA o VARIAS palabras; si son varias, sepáralas con ";" (ej: "ottanta;anno").
   · categoria: UNA o VARIAS 'categorías'; si son varias, sepáralas con ";" (ej: "num;noum").
   Ejemplo correcto de los 3 campos: "ottant'anni|ottanta;anno|num"
4. CATEGORIAS (usa estos SOLO estos códigos):
   - noun: Sustantivo
   - verb: Verbo (en cualquier conjugación, el lema es el infinitivo)
   - adj: Adjetivo
   - det: Determinante (artículos, demostrativos, posesivos)
   - pron: Pronombre
   - adp: Preposición/Adposición
   - conj: Conjunción
   - adv: Adverbio
   - propn: Nombre propio
   - part: Partícula (negaciones, etc.)
   - intj: Interjección
   - num: Número (cifras y numerales). En compuestos numeral+sustantivo se usa num.
   - foreign: Palabra de otro idioma
   - onom: Onomatopeya
   - other: Otros
5. PALABRAS CON APÓSTROFO (CRÍTICO en italiano, francés e inglés).
   El campo LEMA NUNCA puede contener un apóstrofo. Está PROHIBIDO repetir la palabra original como lema.
   Elige SIEMPRE una de estas dos salidas:

   A) DOS LEMAS unidos por ";" cuando el apóstrofo une dos palabras con significado propio,
      cada lema escrito en su forma de diccionario COMPLETA (nunca truncada).
      · NUMERAL + SUSTANTIVO en italiano -> SIEMPRE se separa (regla fija, sin excepciones):
          "ottant'anni"   -> "ottanta;anno"
          "vent'anni"     -> "venti;anno"
          "mezz'ora"      -> "mezza;ora"
      · PRONOMBRE + VERBO (el pronombre aporta significado):
          "j'ai"    -> "je;avoir"
          "I'm"     -> "I;be"
          "m'aveva" -> "mi;avere"
          "c'è"     -> "ci;essere"
   B) UN SOLO LEMA cuando la parte elidida es un artículo o preposición sin significado propio:
          "l'homme"   -> "homme"
          "l'amico"   -> "amico"
          "c'est"     -> "être"
          "d'Artagnan"-> "Artagnan"
          "dog's"     -> "dog"
          "years'"    -> "year"


   La CATEGORÍA es la del núcleo: en "ottant'anni" el núcleo es el numeral -> num.
   Ante la duda entre A y B, usa A (conservar los dos lemas siempre es mejor que descartar uno).
Elige la opción que mejor se adapte al contexto de la oración. Es muy importante sobre todo en francés, inglés, e italiano.
6. **IMPORTANTE**: Todos los lemas deben estar en el idioma '$idioma'. No uses lemas en otro idioma a menos que la palabra sea extranjera (foreign).
7. Responde solo con el JSON, sin explicaciones ni markdown.
8. EVALUACIÓN DE ÍNDICES INDEPENDIENTES: No te dejes llevar por la longitud de la oración. Cuando proceses un ID (ej: "60"), localiza visualmente esa palabra exacta en el texto original, 
determina qué rol juega estrictamente en su entorno inmediato y genera su lema. Prohibido duplicar lemas de IDs contiguos.
   
EJEMPLOS DE DESAMBIGUACIÓN (IMPORTANTE):
- Texto: "El cura cura la herida."
  - "cura" (1): Es el sujeto (quién hace la acción) -> noun. Lema: "cura".
  - "cura" (2): Es la acción -> verb. Lema: "curar".
  - Resultado parcial: "cura|cura|noun", "cura|curar|verb"
- Texto: "El vino tinto es bueno."
  - "vino": Sustantivo (bebida). Lema: "vino". Tipo: noun.
- Texto: "Ayer yo vino Juan." (Gramaticalmente incorrecto pero analiza según intención común) o "Juan vino ayer."
  - "vino": Acción de llegar. Lema: "venir". Tipo: verb.
   

═══ EJEMPLO ($idioma) ═══
Texto original: "${ejemplo["texto"]}"
Palabras: ${ejemplo["map"]}
Respuesta:
${ejemplo["respuesta"]}

═══ ENTRADA ═══
Texto original: "$texto"
Palabras (JSON con índices): $lemasMapStr

Ahora procesa la ENTRADA.
""";
}
