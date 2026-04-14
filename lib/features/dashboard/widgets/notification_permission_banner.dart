// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// ─────────────────────────────────────────
//
// Dashboard banner that appears when the Android notification
// permission is denied. Tap → open app settings. Re-checks on app
// resume so the banner disappears automatically once the vendor
// grants the permission from system settings.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/push_notification_service.dart';

class NotificationPermissionBanner extends StatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  State<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<NotificationPermissionBanner>
    with WidgetsBindingObserver {
  bool _granted = true; // default true so banner stays hidden until checked

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!Platform.isAndroid) return; // iOS is handled by Firebase prompt
    try {
      final status = await Permission.notification.status;
      if (!mounted) return;
      if (_granted != status.isGranted) {
        setState(() => _granted = status.isGranted);
      }
    } catch (_) {
      // Permission check failed — leave banner hidden.
    }
  }

  Future<void> _onTap() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied || status.isDenied) {
      // Try to request first; if permanently denied, fall back to settings.
      final result = await Permission.notification.request();
      if (result.isGranted) {
        if (!mounted) return;
        setState(() => _granted = true);
        // Re-register the token now that we can actually show notifications.
        if (mounted) {
          // ignore: use_build_context_synchronously
          context.read<PushNotificationService>().refreshRegistration();
        }
        return;
      }
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Material(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_off_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications are off',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.deepOrange,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enable notifications to receive new-order alerts.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
