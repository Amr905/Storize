import 'package:storize_app/router/deep_link.dart';
import 'package:storize_model/storize_model.dart';

/// Route names and typed location builders.
///
/// Navigation choices:
/// - S-05 (filters sheet) and S-10 (remove dialog) are shown imperatively
///   with `showModalBottomSheet` / `showDialog` by their screens; they have
///   no route, so system back dismisses them and they never survive a
///   process restart.
/// - S-09 (target detail) lives inside the Targets branch so the tab keeps
///   its own back stack (the bottom bar stays visible).
/// - Every other full-screen page is a top-level route above the tab shell.
abstract final class Routes {
  // Names.
  static const String welcome = 'welcome';
  static const String login = 'login';
  static const String setup = 'setup';
  static const String library = 'library';
  static const String storyViewer = 'story';
  static const String postViewer = 'post';
  static const String targets = 'targets';
  static const String addTarget = 'addTarget';
  static const String targetDetail = 'targetDetail';
  static const String activity = 'activity';
  static const String health = 'health';
  static const String settings = 'settings';
  static const String account = 'account';
  static const String lock = 'lock';

  // Paths.
  static const String welcomePath = '/welcome';
  static const String loginPath = '/login';
  static const String setupPath = '/setup';
  static const String libraryPath = '/library';
  static const String targetsPath = '/targets';
  static const String addTargetPath = '/targets/add';
  static const String activityPath = '/activity';
  static const String healthPath = '/activity/health';
  static const String settingsPath = '/settings';
  static const String accountPath = '/account';
  static const String lockPath = '/lock';

  /// S-04 with optional filters.
  static String libraryLocation({ContentKind? kind, int? targetId}) =>
      LibraryLink(kind: kind, targetId: targetId).location;

  /// S-06.
  static String storyLocation(int contentId) => StoryLink(contentId).location;

  /// S-15.
  static String postLocation(int contentId) => PostLink(contentId).location;

  /// S-09.
  static String targetDetailLocation(int targetId) => '/targets/$targetId';

  /// S-12, optionally scrolled to [section].
  static String settingsLocation({SettingsSection? section}) =>
      SettingsLink(section: section).location;
}
