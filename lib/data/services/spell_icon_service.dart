import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up spell icons on Wowhead.
///
/// Icons are Blizzard's artwork, so they are never bundled with the app;
/// the browser loads them from Wowhead's CDN at runtime.
class SpellIconService {
  SpellIconService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Icon file names are lower-case words with underscores, e.g.
  /// `spell_shaman_lavaburst`. Anything else is rejected before it is put
  /// into a URL.
  static final validName = RegExp(r'^[a-z0-9_\-]+$');

  /// The icon file name for [spellId], or `null` if Wowhead doesn't know it.
  Future<String?> iconName(int spellId) async {
    final response = await _client
        .get(Uri.parse('https://nether.wowhead.com/tooltip/spell/$spellId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    final icon = json['icon'];
    if (icon is! String) return null;
    final name = icon.toLowerCase();
    return validName.hasMatch(name) ? name : null;
  }

  /// The 56×56 image for an icon name from [iconName].
  Uri imageUrl(String iconName) =>
      Uri.parse('https://wow.zamimg.com/images/wow/icons/large/$iconName.jpg');
}
