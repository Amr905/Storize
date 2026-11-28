import 'dart:async';

import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/src/ports/linked_content_source.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/link_parser.dart';
import 'package:storize_domain/src/usecases/save_preview_items.dart';
import 'package:storize_model/storize_model.dart';

/// What [SaveFromLink.lookup] found for a link (FR-80).
@immutable
sealed class LinkLookup {
  const LinkLookup();
}

/// The text holds no supported Instagram link.
final class LinkUnsupported extends LinkLookup {
  /// Creates the result.
  const LinkUnsupported();
}

/// The link was read; [preview] says what it holds.
final class LinkFound extends LinkLookup {
  /// Creates the result.
  const LinkFound(this.preview);

  /// What the link points at.
  final LinkPreview preview;
}

/// The content is not there any more: an expired story, a removed post or
/// highlight.
final class LinkGone extends LinkLookup {
  /// Creates the result.
  const LinkGone(this.kind);

  /// What the link pointed at.
  final LinkKind kind;
}

/// The lookup failed ([failure] is rate limited, session, private account,
/// network, ...).
final class LinkFailed extends LinkLookup {
  /// Creates the result.
  const LinkFailed(this.failure);

  /// Why the lookup failed.
  final Failure failure;
}

/// What a link points at, ready to show and to save (FR-80).
@immutable
final class LinkPreview {
  /// Creates a preview. [items] and [savedContentIds] are copied.
  LinkPreview({
    required this.link,
    required this.user,
    required List<RemoteContent> items,
    this.focus,
    Map<String, int> savedContentIds = const {},
    this.title,
  }) : items = List.unmodifiable(items),
       savedContentIds = Map.unmodifiable(savedContentIds);

  /// The parsed link.
  final ParsedLink link;

  /// The owner.
  final RemoteUser user;

  /// Every item found: one for a story, post or reel; all items for a
  /// highlight.
  final List<RemoteContent> items;

  /// The one item the link names (a story, post, reel or the highlight item
  /// of `story_media_id`), or null for a whole highlight.
  final RemoteContent? focus;

  /// The highlight title, when there is one.
  final String? title;

  /// The content row ids of items that are in the gallery already, by remote
  /// id.
  final Map<String, int> savedContentIds;

  /// Whether [item] is saved already.
  bool isSaved(RemoteContent item) =>
      savedContentIds.containsKey(item.remoteId);

  /// How many [items] are not saved yet.
  int get unsavedCount => items.where((i) => !isSaved(i)).length;

  /// True when the link names one item and it is saved already.
  bool get focusSaved => focus != null && isSaved(focus!);
}

/// Saves what an Instagram link points at (FR-80).
///
/// 1. [lookup] reads the link, in the foreground at interactive priority:
///    a story by `resolveUser` + `fetchStories`, a post or reel by shortcode,
///    a highlight with its owner (the last two through
///    [LinkedContentSource]). Reads only: nothing is marked as seen.
/// 2. [save] stores the items through [SavePreviewItems] (rows, download now,
///    "hide from gallery", a paused `preview_only` target for an account that
///    is not tracked). Media goes to the gallery only there.
///
/// Logs INFO lines with the link kind and the outcome only, never the link,
/// username or ids.
final class SaveFromLink {
  /// Creates the use case. `onFinished` runs at the end of every lookup (the
  /// composition closes the in-page session there).
  SaveFromLink({
    required this._platform,
    required this._source,
    required this._targets,
    required this._content,
    required this._save,
    this._log,
    this._onFinished,
    this.stepTimeout = const Duration(seconds: 90),
  });

  final ContentPlatform _platform;
  final LinkedContentSource _source;
  final TargetRepo _targets;
  final ContentRepo _content;
  final SavePreviewItems _save;
  final DiagnosticLog? _log;
  final Future<void> Function()? _onFinished;

  /// The longest one platform call may take before it is a network failure.
  final Duration stepTimeout;

  static const String _tag = 'link';

  /// The policy of a user-initiated foreground read.
  static const ExtractionPolicy policy = ExtractionPolicy.directThenPage;

  /// Parses [text] (pasted or shared) and looks the link up.
  Future<LinkLookup> lookupText(String text) async {
    final link = LinkParser.parse(text);
    if (link == null) {
      _info('lookup kind=none outcome=unsupported');
      return const LinkUnsupported();
    }
    return lookup(link);
  }

  /// Looks [link] up.
  Future<LinkLookup> lookup(ParsedLink link) async {
    LinkLookup result;
    try {
      result = await _lookup(link);
    } on Object {
      result = const LinkFailed(UnknownFailure(null, 'lookup_threw'));
    } finally {
      await _finish();
    }
    _info('lookup kind=${link.kind.name} outcome=${_outcome(result)}');
    return result;
  }

  Future<LinkLookup> _lookup(ParsedLink link) async {
    switch (link.kind) {
      case LinkKind.story:
        return _story(link);
      case LinkKind.post:
      case LinkKind.reel:
        final r = await _step(
          () => _source.fetchPostByShortcode(link.shortcode!, policy: policy),
        );
        return _fromItems(link, r, (items) => items.items.take(1).toList());
      case LinkKind.highlight:
        final r = await _step(
          () => _source.fetchHighlightWithOwner(
            link.highlightId!,
            policy: policy,
          ),
        );
        return _fromItems(link, r, (items) => items.items);
    }
  }

  Future<LinkLookup> _story(ParsedLink link) async {
    final resolved = await _step(() => _platform.resolveUser(link.username!));
    switch (resolved) {
      case Err(:final failure):
        return _failure(link.kind, failure);
      case Ok(:final value):
        final user = value;
        if (user.blockedByViewer ||
            (user.isPrivate && !user.followedByViewer)) {
          return const LinkFailed(TargetNotVisible());
        }
        final stories = await _step(
          () => _platform.fetchStories([user.remoteUserId], policy: policy),
        );
        switch (stories) {
          case Err(:final failure):
            return _failure(link.kind, failure);
          case Ok(:final value):
            final mine = [
              for (final c
                  in value[user.remoteUserId] ?? const <RemoteContent>[])
                if (c.kind == ContentKind.story && c.remoteId == link.mediaPk)
                  c,
            ];
            if (mine.isEmpty) return const LinkGone(LinkKind.story);
            return LinkFound(
              await _preview(link, user, mine, focus: mine.first),
            );
        }
    }
  }

  Future<LinkLookup> _fromItems(
    ParsedLink link,
    Result<LinkedItems> r,
    List<RemoteContent> Function(LinkedItems) pick,
  ) async {
    switch (r) {
      case Err(:final failure):
        return _failure(link.kind, failure);
      case Ok(:final value):
        final items = pick(value);
        if (items.isEmpty) return LinkGone(link.kind);
        RemoteContent? focus;
        if (link.kind == LinkKind.highlight) {
          final want = link.mediaPk;
          if (want != null) {
            focus = items.where((c) => c.remoteId == want).firstOrNull;
          }
        } else {
          focus = items.first;
        }
        return LinkFound(
          await _preview(
            link,
            value.user,
            items,
            focus: focus,
            title: link.kind == LinkKind.highlight
                ? items.first.extras[HighlightExtras.title] as String?
                : null,
          ),
        );
    }
  }

  LinkLookup _failure(LinkKind kind, Failure failure) =>
      failure is TargetNotFound ? LinkGone(kind) : LinkFailed(failure);

  Future<LinkPreview> _preview(
    ParsedLink link,
    RemoteUser user,
    List<RemoteContent> items, {
    RemoteContent? focus,
    String? title,
  }) async => LinkPreview(
    link: link,
    user: user,
    items: items,
    focus: focus,
    title: title,
    savedContentIds: await _known(user, items),
  );

  /// Items the gallery has already (stored and downloaded).
  Future<Map<String, int>> _known(
    RemoteUser user,
    List<RemoteContent> items,
  ) async {
    try {
      final target = await _targets.getByRemoteUserId(
        _platform.id,
        user.remoteUserId,
      );
      if (target == null) return const {};
      final stored = await _content.listByTarget(target.id);
      final done = {
        for (final c in stored)
          if (c.content.status == ContentStatus.done)
            (c.content.kind, c.content.remoteId): c.content.id,
      };
      return {
        for (final i in items) i.remoteId: ?done[(i.kind, i.remoteId)],
      };
    } on Object {
      return const {};
    }
  }

  /// Saves the items of [preview] now: the one it names, or with
  /// [all] every item that is not saved yet. Returns null when there is
  /// nothing to save.
  Future<PreviewSaveResult?> save(
    LinkPreview preview, {
    bool all = false,
  }) async {
    final focus = preview.focus;
    final items = all || focus == null
        ? [
            for (final i in preview.items)
              if (!preview.isSaved(i)) i,
          ]
        : [if (!preview.isSaved(focus)) focus];
    if (items.isEmpty) return null;
    final result = await _save.call(user: preview.user, items: items);
    _info(
      'save kind=${preview.link.kind.name} n=${items.length} '
      'saved=${result.saved} failed=${result.failed}',
    );
    return result;
  }

  Future<Result<T>> _step<T>(Future<Result<T>> Function() call) async {
    try {
      return await call().timeout(stepTimeout);
    } on TimeoutException {
      return const Err(NetworkFailure());
    } on Object {
      return const Err(UnknownFailure(null, 'platform_threw'));
    }
  }

  Future<void> _finish() async {
    try {
      await _onFinished?.call();
    } on Object {
      // Clean-up only.
    }
  }

  static String _outcome(LinkLookup r) => switch (r) {
    LinkFound() => 'found',
    LinkGone() => 'gone',
    LinkUnsupported() => 'unsupported',
    LinkFailed(:final failure) => 'failure_${failure.runtimeType}',
  };

  void _info(String message) => _log?.log(LogLevel.info, _tag, message);
}
