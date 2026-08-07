/// Durable Collection Store — Implementation Specification IS-R56.
/// The ONE owner of read-modify-write against a durable collection key.
///
/// WHY THIS EXISTS — a defect the R56 audit PROVED, not one it suspected.
///
/// Three repositories in this codebase persist a whole collection under a
/// single key and mutate it with the same shape:
///
///     read the whole list  ->  change it in memory  ->  write the whole list
///
///     RealNotificationService  schedule / cancel / cancelAllForExperience /
///                              deliverDue
///     ActivityRepository       record
///     IntentRepository         save / updateStatus / delete
///
/// Every one of them AWAITED between the read and the write. In Dart that is
/// the whole problem: an `await` is a yield point, so two overlapping calls
/// both read the same list, both mutate their own copy, and the second write
/// silently discards the first.
///
/// The audit measured it rather than reasoning about it. Ten concurrent
/// `schedule()` calls:
///
///     scheduled 10 concurrently, pending 1        <- NINE LOST
///
/// and two concurrent `deliverDue()` calls against one due notification:
///
///     1 scheduled, presented 2 time(s)
///
/// The second breaks a contract the method states in its own doc comment
/// ("so a notification is delivered exactly once"), because it presented
/// BEFORE it persisted the remainder.
///
/// Reachable in production, not just in a test: `NotificationCapability`
/// exposes schedule/cancel to any running Experience, `BackgroundCoordinator`
/// polls `deliverDue`, and the workspace can run several Experiences at once.
///
/// HOW THIS FIXES IT — BY REMOVING THE YIELD, NOT BY ADDING A LOCK.
///
/// [update] resolves `SharedPreferences` FIRST, then runs the caller's
/// mutation and the write with no `await` in between. Dart is single-threaded:
/// with no yield point inside the critical section, two concurrent callers
/// CANNOT interleave. The race is structurally impossible rather than guarded
/// against.
///
/// This is enforced by the type system, which is the point of the design:
/// [update]'s callback is a plain synchronous function, NOT a `FutureOr`. Code
/// that tries to await inside the critical section does not compile.
///
/// AN EARLIER DESIGN WAS WRONG AND IS RECORDED HERE SO IT IS NOT RETRIED.
/// The first implementation serialised callers through a static per-key future
/// chain and allowed an async mutation. It deadlocked: `flutter_test` tears
/// down a zone between tests, and a chain entry left behind by one test was
/// awaited forever by the next, hanging widget tests that record activity.
/// Static cross-test state plus cross-zone futures is a trap. The lock was not
/// just heavier than needed — it was the reason a lock appeared necessary at
/// all, because an async callback reintroduced the very yield the lock existed
/// to survive.
///
/// WHAT THIS OWNS, AND NOTHING ELSE. It sequences a read and a write. It knows
/// nothing about notifications, activity, intents, retention, or what any of
/// those collections mean — each repository keeps its own types, its own JSON
/// and its own semantics. This owns exactly the critical section they were all
/// missing, and it holds no state of its own.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes one durable key with no yield point in between.
class DurableCollectionStore {
  const DurableCollectionStore();

  /// Runs [mutate] against the current raw value of [key] and writes whatever
  /// it returns.
  ///
  /// [mutate] receives the stored string (or null when the key is absent) and
  /// returns the string to store, or null to remove the key, plus a result
  /// handed back to the caller.
  ///
  /// **[mutate] is synchronous by design.** Everything between the read and
  /// the write must run in one uninterrupted turn of the event loop; an async
  /// callback would reintroduce exactly the interleaving this exists to
  /// remove. Work that must await belongs on either side of this call — see
  /// `RealNotificationService.deliverDue`, which claims here and presents
  /// afterwards.
  Future<T> update<T>(
    String key,
    ({String? value, T result}) Function(String? current) mutate,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // ── critical section: no `await` from here to the write ──
    // `SharedPreferences` updates its in-memory cache synchronously when
    // set/remove is CALLED, so the value is visible to any concurrent caller
    // before this method yields again.
    final outcome = mutate(prefs.getString(key));
    final write = outcome.value == null
        ? prefs.remove(key)
        : prefs.setString(key, outcome.value!);
    // ── end critical section ──

    await write;
    return outcome.result;
  }

  /// Reads the raw stored value.
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Removes a key.
  Future<void> clear(String key) =>
      update<void>(key, (_) => (value: null, result: null));
}
