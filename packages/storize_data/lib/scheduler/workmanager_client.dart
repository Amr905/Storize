import 'package:workmanager/workmanager.dart';

/// The part of `Workmanager` that the scheduler uses.
///
/// It exists so the scheduler can be tested without the plugin channel.
abstract interface class WorkmanagerClient {
  /// Registers or replaces a periodic task.
  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required Constraints constraints,
    Duration? initialDelay,
    ExistingPeriodicWorkPolicy policy = ExistingPeriodicWorkPolicy.update,
  });

  /// Registers a one-off task.
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
    Duration? initialDelay,
  });

  /// Cancels every task.
  Future<void> cancelAll();
}

/// The production [WorkmanagerClient] over the plugin singleton.
final class PluginWorkmanagerClient implements WorkmanagerClient {
  /// Creates the client.
  PluginWorkmanagerClient([Workmanager? plugin])
    : _plugin = plugin ?? Workmanager();

  final Workmanager _plugin;

  @override
  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required Constraints constraints,
    Duration? initialDelay,
    ExistingPeriodicWorkPolicy policy = ExistingPeriodicWorkPolicy.update,
  }) => _plugin.registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: frequency,
    constraints: constraints,
    initialDelay: initialDelay,
    existingWorkPolicy: policy,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 5),
  );

  @override
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
    Duration? initialDelay,
  }) => _plugin.registerOneOffTask(
    uniqueName,
    taskName,
    constraints: constraints,
    existingWorkPolicy: policy,
    inputData: inputData,
    initialDelay: initialDelay,
    expedited: expedited,
    outOfQuotaPolicy: expedited
        ? OutOfQuotaPolicy.runAsNonExpeditedWorkRequest
        : null,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 5),
  );

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
