import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'sync_event.dart';
import 'sync_state.dart';
import '../../repositories/booking_repository.dart';

/// BLoC for managing synchronization between local database and external APIs.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final BookingRepository _repository;
  Timer? _syncTimer;

  SyncBloc({required BookingRepository repository})
      : _repository = repository,
        super(SyncInitial()) {
    on<StartSync>(_onStartSync);
    on<ScheduleSync>(_onScheduleSync);
    on<CancelScheduledSync>(_onCancelScheduledSync);
    on<SyncCompleted>(_onSyncCompleted);
    on<SyncFailed>(_onSyncFailed);
  }

  Future<void> _onStartSync(StartSync event, Emitter<SyncState> emit) async {
    emit(SyncInProgress());
    try {
      await _repository.syncAllBookings();
      add(const SyncCompleted('Synchronization completed successfully'));
    } catch (e) {
      add(SyncFailed('Synchronization failed: $e'));
    }
  }

  void _onScheduleSync(ScheduleSync event, Emitter<SyncState> emit) {
    // Cancel any existing timer
    _syncTimer?.cancel();

    // Schedule new periodic sync
    _syncTimer = Timer.periodic(event.interval, (_) {
      add(const StartSync());
    });

    emit(SyncScheduled(event.interval));
  }

  void _onCancelScheduledSync(
      CancelScheduledSync event, Emitter<SyncState> emit) {
    _syncTimer?.cancel();
    _syncTimer = null;
    emit(SyncInitial());
  }

  void _onSyncCompleted(SyncCompleted event, Emitter<SyncState> emit) {
    emit(SyncSuccess(event.message));
  }

  void _onSyncFailed(SyncFailed event, Emitter<SyncState> emit) {
    emit(SyncError(event.error));
  }

  @override
  Future<void> close() {
    _syncTimer?.cancel();
    return super.close();
  }
}
