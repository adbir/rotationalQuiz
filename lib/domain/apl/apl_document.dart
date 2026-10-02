import 'apl_expression.dart';

/// The name SimC uses for the top-level list (`actions=` / `actions+=`).
const defaultActionListName = 'default';

/// A single line of an action priority list, e.g.
/// `actions.single_target+=/lava_burst,if=buff.lava_surge.up`.
class AplAction {
  const AplAction({
    required this.listName,
    required this.index,
    required this.name,
    required this.options,
    required this.rawLine,
    this.condition,
    this.conditionError,
    this.comments = const [],
  });

  /// The list this action belongs to, e.g. `single_target`.
  final String listName;

  /// Zero-based position within its list.
  final int index;

  /// The action name, e.g. `lava_burst`.
  final String name;

  /// All `key=value` options, including `if`.
  final Map<String, String> options;

  /// The parsed `if=` condition, or `null` when the action is unconditional
  /// (or the condition failed to parse, see [conditionError]).
  final AplExpression? condition;

  /// Set when the `if=` text could not be parsed.
  final String? conditionError;

  /// `#` comment lines directly above this action in the source file.
  final List<String> comments;

  /// The original source line.
  final String rawLine;

  /// The raw `if=` text, if any.
  String? get conditionSource => options['if'];

  /// True for actions flagged `moving=1`, which SimC only considers while the
  /// player is moving.
  bool get onlyWhileMoving => options['moving'] == '1';

  /// The target list for `run_action_list` / `call_action_list`.
  String? get targetListName => options['name'];

  bool get isListJump =>
      name == 'run_action_list' || name == 'call_action_list';
}

/// A named list of [AplAction]s.
class AplActionList {
  const AplActionList(this.name, this.actions, {this.comments = const []});

  final String name;
  final List<AplAction> actions;

  /// Comments directly above the first action of the list.
  final List<String> comments;
}

/// A fully parsed `.simc` action priority list file.
class AplDocument {
  const AplDocument({
    required this.lists,
    required this.source,
    this.origin = 'unknown',
  });

  /// Lists in file order, keyed by name. The top-level list is
  /// [defaultActionListName].
  final Map<String, AplActionList> lists;

  /// The original file contents.
  final String source;

  /// Where the document came from (asset path or URL), for display.
  final String origin;

  AplActionList? operator [](String name) => lists[name];

  /// Parses the contents of a SimC `.simc` file.
  ///
  /// Lines that are not `actions...` assignments are ignored, which makes it
  /// possible to paste a full character profile as well as a bare APL.
  factory AplDocument.parse(String source, {String origin = 'unknown'}) {
    final builders = <String, List<AplAction>>{};
    final listComments = <String, List<String>>{};
    var pendingComments = <String>[];

    final linePattern = RegExp(r'^actions(?:\.([A-Za-z0-9_]+))?(\+?=)(.*)$');

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        pendingComments = [];
        continue;
      }
      if (line.startsWith('#')) {
        pendingComments.add(line.substring(1).trim());
        continue;
      }
      final match = linePattern.firstMatch(line);
      if (match == null) {
        pendingComments = [];
        continue;
      }
      final listName = match.group(1) ?? defaultActionListName;
      final isAppend = match.group(2) == '+=';
      var body = match.group(3)!.trim();
      if (body.startsWith('/')) body = body.substring(1);

      final actions = builders.putIfAbsent(listName, () => []);
      if (!isAppend) {
        // `actions.x=` starts (or restarts) the list.
        actions.clear();
        listComments[listName] = pendingComments;
      }
      // A single line may contain several actions separated by `/`.
      for (final actionText in body.split('/')) {
        if (actionText.trim().isEmpty) continue;
        actions.add(
          _parseAction(
            actionText.trim(),
            listName: listName,
            index: actions.length,
            rawLine: line,
            comments: pendingComments,
          ),
        );
      }
      pendingComments = [];
    }

    return AplDocument(
      lists: {
        for (final entry in builders.entries)
          entry.key: AplActionList(
            entry.key,
            List.unmodifiable(entry.value),
            comments: listComments[entry.key] ?? const [],
          ),
      },
      source: source,
      origin: origin,
    );
  }

  static AplAction _parseAction(
    String text, {
    required String listName,
    required int index,
    required String rawLine,
    required List<String> comments,
  }) {
    final parts = text.split(',');
    final name = parts.first.trim();
    final options = <String, String>{};
    for (final part in parts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq < 0) {
        options[part.trim()] = '1';
      } else {
        options[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
      }
    }

    AplExpression? condition;
    String? conditionError;
    final conditionSource = options['if'];
    if (conditionSource != null && conditionSource.isNotEmpty) {
      try {
        condition = AplExpressionParser.parse(conditionSource);
      } on AplParseException catch (e) {
        conditionError = e.message;
      }
    }

    return AplAction(
      listName: listName,
      index: index,
      name: name,
      options: Map.unmodifiable(options),
      condition: condition,
      conditionError: conditionError,
      comments: List.unmodifiable(comments),
      rawLine: rawLine,
    );
  }
}
