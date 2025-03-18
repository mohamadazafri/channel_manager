import 'package:equatable/equatable.dart';

/// Base class for all synchronization events.
abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start synchronization.
class StartSync extends SyncEvent {
  const StartSync();
}

/// Event to schedule periodic synchronization.
class ScheduleSync extends SyncEvent {
  final Duration interval;

  const ScheduleSync(this.interval);

  @override
  List<Object> get props => [interval];
}

/// Event to cancel scheduled synchronization.
class CancelScheduledSync extends SyncEvent {
  const CancelScheduledSync();
}

/// Event when synchronization completes successfully.
class SyncCompleted extends SyncEvent {
  final String message;

  const SyncCompleted(this.message);

  @override
  List<Object> get props => [message];
}

/// Event when synchronization fails.
class SyncFailed extends SyncEvent {
  final String error;

  const SyncFailed(this.error);

  @override
  List<Object> get props => [error];
}
