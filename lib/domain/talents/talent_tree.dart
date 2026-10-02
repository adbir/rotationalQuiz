/// Static talent tree data for one class, generated from SimulationCraft by
/// `tool/generate_talent_tree.py`.
library;

/// SimC's `talent_tree` enum.
abstract final class TalentTreeKind {
  static const classTree = 1;
  static const spec = 2;
  static const hero = 3;
  static const heroSelection = 4;
}

/// SimC's `trait_node_type_e`.
abstract final class TalentNodeType {
  static const normal = 0;
  static const tiered = 1;
  static const choice = 2;
  static const selection = 3;
}

class TalentEntry {
  const TalentEntry(
    this.id,
    this.name,
    this.token, {
    required this.tree,
    required this.maxRanks,
    required this.specs,
    required this.subTree,
  });

  /// Trait node entry id.
  final int id;
  final String name;

  /// SimC token, as used by `talent.<token>` in APLs.
  final String token;
  final int tree;
  final int maxRanks;

  /// Specs that can take this entry; empty means every spec of the class.
  final List<int> specs;

  /// Hero tree id for hero talents and hero tree selection entries.
  final int subTree;

  bool availableTo(int specId) => specs.isEmpty || specs.contains(specId);
}

class TalentNode {
  const TalentNode(this.id, this.type, this.entries);

  final int id;
  final int type;

  /// In the order used by the choice index of export strings.
  final List<TalentEntry> entries;
}

class TalentTree {
  const TalentTree({
    required this.classId,
    required this.build,
    required this.nodes,
  });

  final int classId;

  /// WoW build the data was generated from.
  final String build;

  /// Sorted by node id, which is the order of export strings.
  final List<TalentNode> nodes;
}
