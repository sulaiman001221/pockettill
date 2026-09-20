/// Shared flag so a pull doesn't run in the middle of a push: a stock or
/// balance change the server has already applied but this device hasn't yet
/// marked as sent would otherwise be counted twice (once in the server's
/// number, once as an unsent local change) until the next pull.
class SyncCoordinator {
  SyncCoordinator._();

  static bool pushInFlight = false;
}
