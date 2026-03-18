import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../viewmodel/notifications_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsViewModel _vm;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = NotificationsViewModel(
      apiService: context.read<ApiService>(),
    );
    _vm.fetchNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            Consumer<NotificationsViewModel>(
              builder: (_, vm, _) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'mark_all') vm.markAllAsRead();
                    if (value == 'clear_read') vm.clearRead();
                  },
                  itemBuilder: (_) => [
                    if (vm.unreadCount > 0)
                      const PopupMenuItem(
                        value: 'mark_all',
                        child: Row(
                          children: [
                            Icon(Icons.done_all_rounded,
                                size: 20, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('Mark all as read'),
                          ],
                        ),
                      ),
                    if (vm.hasReadNotifications)
                      const PopupMenuItem(
                        value: 'clear_read',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_outlined,
                                size: 20, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Clear read'),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<NotificationsViewModel>(
          builder: (context, vm, _) {
            // ── Loading ──────────────────────────────────────
            if (vm.isLoading) {
              return const ShimmerList(itemCount: 8, itemHeight: 76);
            }

            // ── Error ────────────────────────────────────────
            if (vm.status == NotificationsStatus.error &&
                !vm.hasNotifications) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 56, color: AppColors.textHint),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        vm.error ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      ElevatedButton.icon(
                        onPressed: vm.fetchNotifications,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ── Empty ────────────────────────────────────────
            if (!vm.hasNotifications) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      "You'll see order updates, reviews,\nand alerts here",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            // ── Notification List ────────────────────────────
            final items = vm.notifications;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: vm.refresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + (vm.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // ── Load-more indicator ─────────────────────
                  if (index == items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSizes.lg),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final n = items[index];

                  // ── Date header ─────────────────────────────
                  Widget? header;
                  if (index == 0 ||
                      !_isSameDay(
                          items[index - 1].createdAt, n.createdAt)) {
                    header = Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xs),
                      child: Text(
                        _dateLabel(n.createdAt),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ?header,
                      Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(right: AppSizes.lg),
                          color: AppColors.error,
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => vm.deleteNotification(n.id),
                        child: _NotificationTile(
                          notification: n,
                          onTap: () {
                            if (!n.isRead) {
                              vm.markAsRead([n.id]);
                            }
                            if (n.orderId != null) {
                              final pushService =
                                  context.read<PushNotificationService>();
                              Navigator.of(context).pop();
                              pushService.onNavigateToOrder?.call(n.orderId!);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Notification Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final iconData = _iconFor(n.type);
    final iconColor = _colorFor(n.type);
    final isRead = n.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? null : AppColors.primary.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.sm + 4),
        child: Opacity(
          opacity: isRead ? 0.45 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Unread dot ────────────────────────────────────
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 14),

              // ── Type icon ─────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isRead ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(iconData,
                    color: isRead ? AppColors.textHint : iconColor, size: 22),
              ),
              const SizedBox(width: AppSizes.sm + 4),

              // ── Content ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      isRead ? FontWeight.w400 : FontWeight.w700,
                                  color: isRead
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          n.timeAgo.isNotEmpty
                              ? n.timeAgo
                              : _timeAgo(n.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isRead
                                ? AppColors.textHint
                                : AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1d ago';
    return '${diff.inDays}d ago';
  }

  static IconData _iconFor(String type) {
    if (type.contains('new_order') || type == 'order_placed') {
      return Icons.shopping_bag_rounded;
    }
    if (type == 'order_confirmed' ||
        type == 'order_preparing' ||
        type == 'order_ready') {
      return Icons.restaurant_rounded;
    }
    if (type == 'order_cancelled') return Icons.cancel_outlined;
    if (type == 'order_delivered') return Icons.done_all_rounded;
    if (type.contains('payment') || type.contains('refund')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (type == 'review_received') return Icons.star_rounded;
    if (type.contains('scheduled')) return Icons.event_rounded;
    if (type.contains('kyc') || type.contains('account')) {
      return Icons.verified_user_outlined;
    }
    if (type == 'system' || type == 'promotion') {
      return Icons.campaign_rounded;
    }
    return Icons.notifications_rounded;
  }

  static Color _colorFor(String type) {
    if (type.contains('new_order') || type == 'order_placed') {
      return AppColors.info;
    }
    if (type == 'order_confirmed' ||
        type == 'order_preparing' ||
        type == 'order_ready' ||
        type == 'order_delivered') {
      return AppColors.success;
    }
    if (type == 'order_cancelled') return AppColors.error;
    if (type.contains('payment') || type.contains('refund')) {
      return AppColors.warning;
    }
    if (type == 'review_received') return AppColors.ratingStar;
    if (type.contains('scheduled')) return AppColors.info;
    if (type.contains('kyc') || type.contains('account')) {
      return AppColors.textSecondary;
    }
    if (type == 'system' || type == 'promotion') return AppColors.primary;
    return AppColors.textSecondary;
  }
}
