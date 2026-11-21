import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/onboarding/login_host_policy.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Where the S-02 flow is.
enum LoginPhase {
  /// Taking the WebView lease.
  starting,

  /// The Instagram page is showing.
  ready,

  /// Cookies found; checking the session (IG-4).
  connecting,

  /// A different account logged in; waiting for the user's answer.
  confirmSwitch,

  /// Done.
  connected,

  /// Something went wrong; see [LoginState.error].
  error,
}

/// Why S-02 shows an error.
enum LoginError {
  /// No internet.
  network,

  /// The page failed to load.
  page,

  /// Instagram asks for a checkpoint or restricted the account.
  checkpoint,

  /// The session could not be used.
  unusable,

  /// The user declined to switch to a different account.
  wrongAccount,

  /// Another part of the app uses the WebView (page mode, or the lease was lost).
  busy,

  /// The user cancelled.
  cancelled,
}

/// UI state of S-02.
@immutable
class LoginState {
  /// Creates a state.
  const LoginState({
    this.phase = LoginPhase.starting,
    this.progress = 0,
    this.error,
    this.username,
    this.previousUsername,
  });

  /// The phase.
  final LoginPhase phase;

  /// Page load progress, 0 to 100.
  final int progress;

  /// The error, when [phase] is [LoginPhase.error].
  final LoginError? error;

  /// The connected (or candidate) account's username.
  final String? username;

  /// The account that is stored now, during a switch confirmation.
  final String? previousUsername;

  /// Whether the page is still loading.
  bool get loading => phase == LoginPhase.ready && progress < 100;

  /// A copy with changes.
  LoginState copyWith({
    LoginPhase? phase,
    int? progress,
    LoginError? error,
    String? username,
    String? previousUsername,
  }) => LoginState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    error: error,
    username: username ?? this.username,
    previousUsername: previousUsername ?? this.previousUsername,
  );
}

/// Runs S-02: holds the lease, watches the WebView, verifies and stores the
/// session, then wipes the WebView. Never logs or exposes cookie values.
class LoginController extends Notifier<LoginState>
    implements LoginWebViewEvents {
  LoginWebViewController? _web;
  StreamSubscription<void>? _lostSub;
  Completer<bool>? _switchAnswer;
  bool _leaseHeld = false;
  bool _checking = false;
  bool _disposed = false;
  int _generation = 0;

  /// The session of a login that has not been confirmed is kept under this
  /// account id. The `ContentPlatform` given to the login flow reads it for
  /// IG-4. It is cleared as soon as the flow ends.
  static const int stagingAccountId = LoginAccount.unsavedId;

  LoginLease get _lease => ref.read(loginLeaseProvider);

  @override
  LoginState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_lostSub?.cancel());
      _answerSwitch(false);
      if (_leaseHeld) {
        _leaseHeld = false;
        unawaited(_lease.release(LoginLease.owner));
      }
    });
    return const LoginState();
  }

  /// Takes the lease. Call once when S-02 opens.
  Future<void> start() async {
    state = const LoginState();
    _lostSub ??= _lease.onLost.listen((_) => _onLeaseLost());
    final ok = await _lease.tryAcquire(LoginLease.owner);
    if (_disposed) {
      if (ok) await _lease.release(LoginLease.owner);
      return;
    }
    if (!ok) {
      state = const LoginState(phase: LoginPhase.error, error: LoginError.busy);
      return;
    }
    _leaseHeld = true;
    state = const LoginState(phase: LoginPhase.ready);
  }

  void _onLeaseLost() {
    _leaseHeld = false;
    _generation++;
    _answerSwitch(false);
    unawaited(_wipeStaging());
    unawaited(_web?.clearData());
    state = const LoginState(phase: LoginPhase.error, error: LoginError.busy);
  }

  /// Back during login: stops everything and wipes the WebView.
  Future<void> cancel() async {
    _generation++;
    _answerSwitch(false);
    await _wipeStaging();
    await _safeClear();
    state = const LoginState(
      phase: LoginPhase.error,
      error: LoginError.cancelled,
    );
  }

  /// Retry after an error: starts over.
  Future<void> retry() async {
    _generation++;
    final web = _web;
    if (_leaseHeld && web != null && state.error != LoginError.busy) {
      await _safeClear();
      state = const LoginState(phase: LoginPhase.ready);
      await web.reload();
      return;
    }
    if (_leaseHeld) {
      await _lease.release(LoginLease.owner);
      _leaseHeld = false;
    }
    await start();
    await _web?.reload();
  }

  /// The user's answer to "Switch to @new?".
  void answerSwitch({required bool confirm}) => _answerSwitch(confirm);

  void _answerSwitch(bool value) {
    final c = _switchAnswer;
    if (c != null && !c.isCompleted) c.complete(value);
  }

  // LoginWebViewEvents.

  @override
  void onReady(LoginWebViewController controller) => _web = controller;

  @override
  bool allowNavigation(Uri url) => LoginHostPolicy.allows(url);

  @override
  void onBlocked(Uri url) {}

  @override
  void onLoadStart(Uri url) {
    if (state.phase == LoginPhase.ready) {
      state = state.copyWith(progress: 0);
    }
  }

  @override
  void onProgress(int percent) {
    if (state.phase == LoginPhase.ready) {
      state = state.copyWith(progress: percent);
    }
  }

  @override
  void onLoadError(LoginLoadError error) {
    if (state.phase != LoginPhase.ready) return;
    state = LoginState(
      phase: LoginPhase.error,
      error: error == LoginLoadError.network
          ? LoginError.network
          : LoginError.page,
    );
  }

  @override
  void onLoadStop(Uri url) {
    if (state.phase == LoginPhase.ready) state = state.copyWith(progress: 100);
    if (LoginHostPolicy.isInstagram(url)) unawaited(_checkSession());
  }

  Future<void> _checkSession() async {
    final web = _web;
    if (web == null || _checking || state.phase != LoginPhase.ready) return;
    _checking = true;
    final gen = _generation;
    try {
      final cookies = await web.readCookies();
      final ua = await web.userAgent();
      final blob = SessionBlob(
        cookies: cookies,
        userAgent: ua ?? '',
        capturedAt: ref.read(clockProvider).now().toUtc(),
      );
      if (SessionStore.missingCookies(blob).isNotEmpty) return;
      if (gen != _generation) return;
      state = state.copyWith(phase: LoginPhase.connecting);
      await _finish(blob, gen);
    } on Object {
      // Never include the error text: it could carry cookie values.
      if (gen == _generation) _fail(LoginError.unusable);
    } finally {
      _checking = false;
    }
  }

  Future<void> _finish(SessionBlob blob, int gen) async {
    final sessions = ref.read(sessionStoreProvider);
    await sessions.save(stagingAccountId, blob);
    final Result<RemoteUser> verified;
    try {
      verified = await ref.read(contentPlatformProvider).verifySession();
    } on Object {
      await _wipeStaging();
      if (gen == _generation) _fail(LoginError.unusable);
      return;
    }
    if (gen != _generation) {
      await _wipeStaging();
      return;
    }
    final user = switch (verified) {
      Ok<RemoteUser>(:final value) => value,
      Err<RemoteUser>() => null,
    };
    if (user == null) {
      await _wipeStaging();
      final failure = verified.failureOrNull;
      _fail(switch (failure) {
        NetworkFailure() => LoginError.network,
        AccountRestricted() => LoginError.checkpoint,
        _ => LoginError.unusable,
      });
      return;
    }
    final accounts = ref.read(accountRepoProvider);
    final active = await accounts.getActive();
    if (active != null && active.remoteUserId != user.remoteUserId) {
      state = LoginState(
        phase: LoginPhase.confirmSwitch,
        username: user.username,
        previousUsername: active.username,
      );
      final answer = _switchAnswer = Completer<bool>();
      final confirmed = await answer.future;
      _switchAnswer = null;
      if (gen != _generation) {
        await _wipeStaging();
        return;
      }
      if (!confirmed) {
        await _wipeStaging();
        await _safeClear();
        state = LoginState(
          phase: LoginPhase.error,
          error: LoginError.wrongAccount,
          username: user.username,
          previousUsername: active.username,
        );
        return;
      }
    }
    final now = ref.read(clockProvider).now().toUtc();
    final stored = await accounts.upsert(
      LoginAccount(
        id: active?.remoteUserId == user.remoteUserId
            ? active!.id
            : LoginAccount.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: user.remoteUserId,
        username: user.username,
        status: AccountStatus.active,
        connectedAt: now,
        lastSuccessAt: now,
        userAgent: blob.userAgent,
      ),
    );
    await sessions.save(stored.id, blob);
    await _wipeStaging();
    // The session now lives only in the vault.
    await _safeClear();
    state = LoginState(phase: LoginPhase.connected, username: user.username);
  }

  void _fail(LoginError error) {
    unawaited(_safeClear());
    state = LoginState(phase: LoginPhase.error, error: error);
  }

  Future<void> _wipeStaging() async {
    try {
      await ref.read(sessionStoreProvider).clear(stagingAccountId);
    } on Object {
      // Best effort.
    }
  }

  Future<void> _safeClear() async {
    try {
      await _web?.clearData();
    } on Object {
      // Best effort.
    }
  }
}

/// The S-02 controller. Auto-disposed with the page, which releases the lease.
final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );
