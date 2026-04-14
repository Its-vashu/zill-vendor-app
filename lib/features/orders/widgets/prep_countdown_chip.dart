// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// ─────────────────────────────────────────
//
// Live MM:SS countdown rendered on an order card once the vendor has
// accepted it. Anchored on `OrderTimerStore.getDeadline(orderId)`,
// ticks once per second via a local `Timer.periodic`, and goes red
// with a ⚠ "Overdue" label once the deadline is crossed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/constants/app_colors.dart';
import '../services/order_timer_store.dart';

class PrepCountdownChip extends StatefulWidget {
  final int orderId;

  /// Controls the chip's label when no deadline is tracked.
  /// Shown as "—" by default so the slot stays stable.
  final String fallbackLabel;

  const PrepCountdownChip({
    super.key,
    required this.orderId,
    this.fallbackLabel = '—',
  });

  @override
  State<PrepCountdownChip> createState() => _PrepCountdownChipState();
}

class _PrepCountdownChipState extends State<PrepCountdownChip> {
  Timer? _ticker;
  StreamSubscription<void>? _storeSub;

  @override
  void initState() {
    super.initState();
    // Make sure the store is loaded before we render — first build
    // reads synchronously; if cache is empty we trigger a load and
    // setState once it completes.
    if (OrderTimerStore.instance.getDeadline(widget.orderId) == null) {
      OrderTimerStore.instance.preload().then((_) {
        if (mounted) setState(() {});
      });
    }
    _startTicker();
    _storeSub = OrderTimerStore.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _storeSub?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final deadline = OrderTimerStore.instance.getDeadline(widget.orderId);
    if (deadline == null) {
      return _Chip(
        icon: Icons.timer_outlined,
        text: widget.fallbackLabel,
        color: AppColors.textHint,
      );
    }

    final remaining = deadline.difference(DateTime.now());
    final isOverdue = remaining.isNegative;

    // First tick that goes past zero — fire the "time's up" alert
    // exactly once per order (dedup lives inside OrderTimerStore so
    // the chip on the dashboard and the Orders tab agree).
    if (isOverdue &&
        !OrderTimerStore.instance.hasAlerted(widget.orderId)) {
      // Capture the messenger on a synchronous frame so the async
      // gap below can't use a stale context.
      final messenger = ScaffoldMessenger.maybeOf(context);
      final orderId = widget.orderId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final fired = await OrderTimerStore.instance.markAlerted(orderId);
        if (!fired) return; // another chip got there first
        // Buzz the phone even if the vendor isn't looking at the
        // screen. heavyImpact is the loudest non-notification haptic
        // and works without extra packages.
        try {
          HapticFeedback.heavyImpact();
          // Short double-buzz for urgency.
          Future.delayed(const Duration(milliseconds: 220), () {
            HapticFeedback.heavyImpact();
          });
        } catch (_) {
          // Haptics unavailable (emulator / old device) — skip.
        }
        messenger
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order #$orderId — prep time is up!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
      });
    }

    // When overdue we flip the display to "+MM:SS elapsed past deadline"
    // so the vendor can see how long the order has been running late.
    final absSeconds = remaining.abs().inSeconds;
    final minutes = absSeconds ~/ 60;
    final seconds = absSeconds % 60;
    final mmss = '${_two(minutes)}:${_two(seconds)}';

    final Color color;
    final IconData icon;
    final String label;
    if (isOverdue) {
      color = AppColors.error;
      icon = Icons.warning_amber_rounded;
      label = 'Overdue +$mmss';
    } else if (remaining.inMinutes < 5) {
      // Backend Celery Beat task auto-flips the order to `ready`
      // ~5 min before prep-complete so the rider is dispatched in
      // time. Chip makes that visible to the vendor so they know
      // why the card might transition on its own.
      color = AppColors.warning;
      icon = Icons.flash_on_rounded;
      label = 'Ready in $mmss';
    } else {
      color = AppColors.success;
      icon = Icons.timer_rounded;
      label = mmss;
    }

    return _Chip(icon: icon, text: label, color: color);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
