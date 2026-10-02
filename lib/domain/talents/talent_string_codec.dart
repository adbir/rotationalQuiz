import 'talent_tree.dart';

/// A talent build decoded from an in-game export string.
class DecodedTalentBuild {
  const DecodedTalentBuild({
    required this.specId,
    required this.ranks,
    required this.heroTreeId,
  });

  final int specId;

  /// Selected talents by SimC token, with their ranks.
  final Map<String, int> ranks;

  /// The selected hero tree id, or `null` if none.
  final int? heroTreeId;

  Set<String> get tokens => ranks.keys.toSet();
}

class TalentStringException implements Exception {
  const TalentStringException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Decodes Blizzard's talent loadout export strings (the text from
/// "Export" in the in-game talent UI, also used by SimC's `talents=`).
///
/// A straight port of `parse_traits_hash` in SimulationCraft's
/// `engine/player/player.cpp`, which in turn follows
/// `Blizzard_ClassTalentImportExport.lua`.
class TalentStringCodec {
  const TalentStringCodec(this.tree);

  final TalentTree tree;

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  static const _serializationVersion = 2;
  static const _versionBits = 8;
  static const _specBits = 16;
  static const _treeHashBits = 128;
  static const _rankBits = 6;
  static const _choiceBits = 2;
  static const _byteSize = 6;

  /// Reads just the spec id, so callers can give a precise error for a
  /// string from another spec.
  static int specIdOf(String exportString) {
    final reader = _BitReader(_clean(exportString));
    reader.read(_versionBits);
    return reader.read(_specBits);
  }

  DecodedTalentBuild decode(String exportString, {int? expectedSpecId}) {
    final text = _clean(exportString);
    if (text.isEmpty) {
      throw const TalentStringException('Paste a talent export string.');
    }
    for (final char in text.split('')) {
      if (!_alphabet.contains(char)) {
        throw TalentStringException('Invalid character "$char".');
      }
    }
    if ((_versionBits + _specBits + _treeHashBits) > text.length * _byteSize) {
      throw const TalentStringException('The string is too short.');
    }

    final reader = _BitReader(text);
    final version = reader.read(_versionBits);
    final specId = reader.read(_specBits);
    if (version != _serializationVersion) {
      throw TalentStringException(
        'Unsupported export version $version; the game or this app may '
        'need an update.',
      );
    }
    if (expectedSpecId != null && specId != expectedSpecId) {
      throw TalentStringException(
        'This build is for another specialization (spec id $specId).',
      );
    }
    reader.read(_treeHashBits);

    final ranks = <String, int>{};
    int? heroTree;
    for (final node in tree.nodes) {
      if (reader.read(1) == 0) continue; // not selected
      var entry = node.entries.first;
      final maxRank = node.type == TalentNodeType.tiered
          ? node.entries.fold(0, (sum, e) => sum + e.maxRanks)
          : entry.maxRanks;
      var rank = maxRank;

      if (reader.read(1) == 0) {
        rank = 1; // granted, not purchased
      } else {
        if (reader.read(1) == 1) {
          rank = reader.read(_rankBits); // partially ranked
          if (rank > maxRank) {
            throw TalentStringException(
              'Node ${node.id} has $rank of $maxRank ranks; the string may '
              'be from a different game version.',
            );
          }
        }
        if (reader.read(1) == 1) {
          final index = reader.read(_choiceBits);
          if (index >= node.entries.length) {
            throw TalentStringException(
              'Choice $index for node ${node.id} is out of range; the string '
              'may be from a different game version.',
            );
          }
          entry = node.entries[index];
        }
      }

      if (entry.tree == TalentTreeKind.heroSelection) {
        if (entry.availableTo(specId)) heroTree = entry.subTree;
        continue;
      }
      if (entry.tree != TalentTreeKind.hero && !entry.availableTo(specId)) {
        continue;
      }
      if (node.type == TalentNodeType.tiered) {
        var remaining = rank;
        for (final tier in node.entries) {
          if (remaining <= 0) break;
          final allocated = remaining < tier.maxRanks
              ? remaining
              : tier.maxRanks;
          ranks[tier.token] = allocated;
          remaining -= allocated;
        }
      } else {
        ranks[entry.token] = rank;
      }
    }

    // Hero talents only count for the chosen hero tree.
    if (heroTree != null) {
      final otherHero = {
        for (final node in tree.nodes)
          for (final e in node.entries)
            if (e.tree == TalentTreeKind.hero && e.subTree != heroTree) e.token,
      };
      final chosenHero = {
        for (final node in tree.nodes)
          for (final e in node.entries)
            if (e.tree == TalentTreeKind.hero && e.subTree == heroTree) e.token,
      };
      ranks.removeWhere(
        (token, _) => otherHero.contains(token) && !chosenHero.contains(token),
      );
    }

    return DecodedTalentBuild(
      specId: specId,
      ranks: ranks,
      heroTreeId: heroTree,
    );
  }

  static String _clean(String s) => s.trim().replaceAll(RegExp(r'\s'), '');
}

/// Reads little-endian bit fields from Blizzard's base64 variant, where each
/// character holds 6 bits, least significant first.
class _BitReader {
  _BitReader(this._text);

  final String _text;
  var _head = 0;

  int read(int bits) {
    var value = 0;
    for (var i = 0; i < bits; i++) {
      final charIndex = _head ~/ TalentStringCodec._byteSize;
      final bit = _head % TalentStringCodec._byteSize;
      _head++;
      final byte = charIndex < _text.length
          ? TalentStringCodec._alphabet.indexOf(_text[charIndex])
          : 0;
      // Fields wider than 53 bits (the tree hash) are skipped, so overflow
      // of `value` does not matter.
      if (i < 53) value += ((byte >> bit) & 1) << i;
    }
    return value;
  }
}
