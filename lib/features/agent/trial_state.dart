import 'dart:math';

/// Wall time accounts for time with the app closed. Android elapsedRealtime
/// accounts for sleep and cannot be moved backwards by changing the date.
class TrialClock {
  final int wall, elapsed, boot;
  const TrialClock(this.wall, this.elapsed, this.boot);
  factory TrialClock.fromJson(Map<Object?, Object?> json) => TrialClock(
    json['wall'] as int,
    json['elapsed'] as int,
    json['boot'] as int,
  );
}

class TrialState {
  static const duration = Duration(days: 40);
  static const rollbackTolerance = Duration(minutes: 5);
  final int started, effective, wallHigh, elapsed, boot;
  final bool introduced, clockBlocked;
  final String installation;
  const TrialState({
    required this.started,
    required this.effective,
    required this.wallHigh,
    required this.elapsed,
    required this.boot,
    required this.installation,
    this.introduced = false,
    this.clockBlocked = false,
  });

  factory TrialState.start(TrialClock now, String installation) => TrialState(
    started: now.wall,
    effective: now.wall,
    wallHigh: now.wall,
    elapsed: now.elapsed,
    boot: now.boot,
    installation: installation,
  );

  factory TrialState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('trial_version');
    final state = TrialState(
      started: json['started'] as int,
      effective: json['effective'] as int,
      wallHigh: json['wallHigh'] as int,
      elapsed: json['elapsed'] as int,
      boot: json['boot'] as int,
      installation: json['installation'] as String,
      introduced: json['introduced'] as bool,
      clockBlocked: json['clockBlocked'] as bool,
    );
    if (state.started <= 0 ||
        state.effective < state.started ||
        state.wallHigh < state.started ||
        state.elapsed < 0 ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(state.installation)) {
      throw const FormatException('trial_state');
    }
    return state;
  }

  TrialState advance(TrialClock now, {bool? introduced}) {
    final sameBoot = now.boot == boot && now.elapsed >= elapsed;
    final ticks = sameBoot ? now.elapsed - elapsed : now.elapsed;
    final backwards = now.wall + rollbackTolerance.inMilliseconds < wallHigh;
    return TrialState(
      started: started,
      effective: max(effective + max(0, ticks), now.wall),
      wallHigh: max(wallHigh, now.wall),
      elapsed: now.elapsed,
      boot: now.boot,
      installation: installation,
      introduced: introduced ?? this.introduced,
      // After a reboot we cannot measure time powered off with a forged wall
      // clock. Require the user to correct it instead of renewing the trial.
      clockBlocked: backwards && (clockBlocked || !sameBoot),
    );
  }

  int get remainingMillis =>
      max(0, duration.inMilliseconds - (effective - started));
  int get remainingDays =>
      (remainingMillis / Duration.millisecondsPerDay).ceil();
  bool get active => !clockBlocked && remainingMillis > 0;
  Map<String, Object> toJson() => {
    'version': 1,
    'started': started,
    'effective': effective,
    'wallHigh': wallHigh,
    'elapsed': elapsed,
    'boot': boot,
    'installation': installation,
    'introduced': introduced,
    'clockBlocked': clockBlocked,
  };
}
