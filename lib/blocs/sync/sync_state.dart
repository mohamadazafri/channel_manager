import 'package:equatable/equatable.dart';

/// Base class for all synchronization states.
abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

/// Initial sync state.
class SyncInitial extends SyncState {}

/// State when sync is in progress.
class SyncInProgress extends SyncState {}

/// State when sync has been scheduled.
class SyncScheduled extends SyncState {
  final Duration interval;

  const SyncScheduled(this.interval);

  @override
  List<Object> get props => [interval];
}

/// State when sync completes successfully.
class SyncSuccess extends SyncState {
  final String message;

  const SyncSuccess(this.message);

  @override
  List<Object> get props => [message];
}

/// State when sync fails.
class SyncError extends SyncState {
  final String error;

  const SyncError(this.error);

  @override
  List<Object> get props => [error];
}
