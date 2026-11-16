/// Ephemeral counts for one coordinator and tour. No backend writes or storage.
/// A headcount cannot identify a passenger, so it remains separate from QR/list
/// verification rather than assigning people or guessing an overlap.
class PassengerCounterSession {
  PassengerCounterSession({required this.tourId, required this.coordinatorId});

  final int tourId;
  final int coordinatorId;
  int quickCount = 0;
  final Map<String, bool> verified = {};

  bool belongsTo(int tour, int coordinator) =>
      tourId == tour && coordinatorId == coordinator;
}
