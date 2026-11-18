import 'package:flutter/material.dart';

import '../../app/theme.dart';

const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

// Igual que find_commune del backend: sin tildes, eñes, apóstrofos ni mayúsculas
String foldCommune(String text) {
  final lower = text.toLowerCase().replaceAll("'", ' ');
  final plain = lower.split('').map((char) => _accents[char] ?? char).join();
  return plain.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
}

// Nombre del catálogo que corresponde a lo escrito ("aysen" -> "Aysén"), o null
String? matchCommune(String text, List<String> communes) {
  final folded = foldCommune(text);
  if (folded.isEmpty) return null;
  for (final name in communes) {
    if (foldCommune(name) == folded) return name;
  }
  return null;
}

// Comuna pública: se escribe y se elige entre las sugerencias, sin recorrer las 346 comunas.
// La pantalla la completa sola al elegir una dirección del buscador.
class CommuneField extends StatefulWidget {
  const CommuneField({super.key, required this.controller, required this.communes, this.enabled = true});

  final TextEditingController controller;
  final List<String> communes;
  final bool enabled;

  @override
  State<CommuneField> createState() => _CommuneFieldState();
}

class _CommuneFieldState extends State<CommuneField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // Al salir del campo, "aysen" queda como "Aysén"
  void _onFocus() {
    if (_focus.hasFocus) return setState(() {});
    final match = matchCommune(widget.controller.text, widget.communes);
    if (match != null && match != widget.controller.text) widget.controller.text = match;
    setState(() {});
  }

  List<String> get _suggestions {
    final query = foldCommune(widget.controller.text);
    if (!_focus.hasFocus || query.isEmpty || widget.communes.contains(widget.controller.text)) return const [];
    return widget.communes.where((name) => foldCommune(name).contains(query)).take(5).toList();
  }

  void _choose(String name) {
    widget.controller.text = name;
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('commune-field'),
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled && widget.communes.isNotEmpty,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Comuna que verán los adoptantes',
            hintText: 'Escribe la comuna o déjala vacía',
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty || widget.communes.isEmpty) return null;
            return matchCommune(text, widget.communes) == null ? 'Elige una comuna de la lista o déjala vacía.' : null;
          },
        ),
        if (suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: AdoptifySpacing.xs),
            child: Column(
              children: [
                for (final name in suggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.location_city_outlined, color: context.colors.primaryDark),
                    title: Text(name),
                    onTap: () => _choose(name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
