// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// ─────────────────────────────────────────
//
// Lightweight persistent store that maps an order id to its prep-time
// deadline (i.e. the wall-clock moment at which the dish should be
// ready). Backed by SharedPreferences so the countdown survives an
// app restart.
//
// The vendor's flow uses this as the anchor for a live MM:SS
// countdown on the order card:
//   • Accept order with prep_time = N   → deadline = now + N minutes
//   • Start preparing                   → deadline = now + N minutes (reset)
//   • Mark ready / reject / complete    → deadline cleared

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OrderTimerStore {
  static const String _storageKey = 'order_prep_deadlines_v1';
  static const String _alertedKey = 'order_prep_alerted_v1';

  OrderTimerStore._();
  static final OrderTimerStore instance = OrderTimerStore._();

  /// In-memory cache — avoids a SharedPreferences hit on every render.
  /// Populated lazily from disk the first time any method is called.
  final Map<int, DateTime> _deadlines = <int, DateTime>{};

  /// Orders for which we've already fired the "overdue" alert. Persisted
  /// so the vendor doesn't get re-pinged every time they reopen the app
  /// or switch between the Orders and Dashboard tabs (both render the
  /// chip, and we want exactly one ping per order).
  final Set<int> _alerted = <int>{};
  bool _loaded = false;
  Completer<void>? _loadCompleter;

  /// Broadcast stream that fires whenever the map changes — UI widgets
  /// can subscribe to rebuild when a deadline is added/cleared. (They
  /// still tick every second via their own Ticker/StreamBuilder; this
  /// stream only signals *structural* changes, not each second.)
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (_loadCompleter != null) return _loadCompleter!.future;
    _loadCompleter = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final now = DateTime.now();
          decoded.forEach((k, v) {
            final id = int.tryParse(k.toString());
            final ms = (v is num) ? v.toInt() : int.tryParse(v.toString());
            if (id == null || ms == null) return;
            final dt = DateTime.fromMillisecondsSinceEpoch(ms);
            // Drop deadlines that are more than 6 hours old — they're
            // stale (vendor probably forgot / app crashed mid-order).
            if (now.difference(dt).inHours > 6) return;
            _deadlines[id] = dt;
          });
        }
      }

      // Load the per-order alert flags.
      final alertedRaw = prefs.getString(_alertedKey);
      if (alertedRaw != null && alertedRaw.isNotEmpty) {
        final decoded = jsonDecode(alertedRaw);
        if (decoded is List) {
          for (final v in decoded) {
            final id = (v is num) ? v.toInt() : int.tryParse(v.toString());
            if (id != null) _alerted.add(id);
          }
        }
      }
    } catch (_) {
      // Corrupted prefs — start from a clean slate.
      _deadlines.clear();
      _alerted.clear();
    } finally {
      _loaded = true;
      _loadCompleter?.complete();
      _loadCompleter = null;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final asMap = <String, int>{
        for (final e in _deadlines.entries)
          e.key.toString(): e.value.millisecondsSinceEpoch,
      };
      await prefs.setString(_storageKey, jsonEncode(asMap));
      await prefs.setString(_alertedKey, jsonEncode(_alerted.toList()));
    } catch (_) {
      // Non-fatal — timer still works in memory until the app closes.
    }
  }

  /// Mark an order as having fired its overdue alert. Call this from
  /// the countdown chip the first time it renders in the overdue
  /// state so the vendor gets a single vibration/snackbar per order,
  /// not one per widget instance and not one per app restart.
  Future<bool> markAlerted(int orderId) async {
    await _ensureLoaded();
    if (_alerted.contains(orderId)) return false;
    _alerted.add(orderId);
    await _persist();
    return true; // caller should play its side-effect
  }

  bool hasAlerted(int orderId) {
    if (!_loaded) return false;
    return _alerted.contains(orderId);
  }

  /// Record a prep deadline for this order. Starts `now + prepMinutes`.
  Future<void> setDeadline(int orderId, int prepMinutes) async {
    if (prepMinutes <= 0) return;
    await _ensureLoaded();
    _deadlines[orderId] =
        DateTime.now().add(Duration(minutes: prepMinutes));
    _changes.add(null);
    await _persist();
  }

  /// Synchronous read — returns null if no deadline is tracked.
  ///
  /// Call [preload] once at app start so the first UI render already
  /// has the data.
  DateTime? getDeadline(int orderId) {
    if (!_loaded) return null;
    return _deadlines[orderId];
  }

  Future<void> preload() => _ensureLoaded();

  Future<void> clear(int orderId) async {
    await _ensureLoaded();
    final removedDeadline = _deadlines.remove(orderId) != null;
    final removedAlert = _alerted.remove(orderId);
    if (removedDeadline || removedAlert) {
      _changes.add(null);
      await _persist();
    }
  }

  /// Clear every known deadline — used on logout.
  Future<void> clearAll() async {
    await _ensureLoaded();
    if (_deadlines.isEmpty && _alerted.isEmpty) return;
    _deadlines.clear();
    _alerted.clear();
    _changes.add(null);
    await _persist();
  }
}
