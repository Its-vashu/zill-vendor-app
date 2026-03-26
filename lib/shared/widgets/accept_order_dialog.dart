// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../features/orders/viewmodel/orders_viewmodel.dart';

/// Shows the Accept Order dialog.
///
/// Used from both OrdersScreen and DashboardScreen.
/// [onAccept] is called with the selected prep time (minutes) after validation.
void showAcceptOrderDialog({
  required BuildContext context,
  required VendorOrder order,
  required void Function(int prepTime) onAccept,
}) {
  final maxPrepTime = order.items.isEmpty
      ? 30
      : order.items
            .map((i) => i.preparationTime)
            .fold(0, (a, b) => a > b ? a : b)
            .clamp(5, 180);

  final ctrl = TextEditingController(text: maxPrepTime.toString());
  final formKey = GlobalKey<FormState>();
  final currFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Accept Order',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(ctx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.textSecondary,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Items summary ──────────────────────────────────────
                if (order.items.isNotEmpty ||
                    order.itemsSummary.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER ITEMS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (order.items.isNotEmpty)
                          ...order.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity} x ${item.itemName}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    currFmt.format(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...order.itemsSummary.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        const Divider(height: 10, color: AppColors.borderLight),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              currFmt.format(order.totalAmount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // ── Prep time ──────────────────────────────────────────
                const Text(
                  'Estimated Preparation Time (minutes)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Chips + manual input in one StatefulBuilder so typing
                // in the field also updates chip highlight state.
                StatefulBuilder(
                  builder: (_, setChipState) {
                    final selected = int.tryParse(ctrl.text.trim());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [15, 20, 30, 45, 60].map((mins) {
                            final isSelected = selected == mins;
                            return ChoiceChip(
                              label: Text('$mins min'),
                              selected: isSelected,
                              showCheckmark: false,
                              onSelected: (_) {
                                ctrl.text = mins.toString();
                                setChipState(() {});
                              },
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderLight,
                                ),
                              ),
                              backgroundColor: AppColors.surface,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setChipState(() {}),
                          decoration: InputDecoration(
                            suffixText: 'min',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null) return 'Enter a valid number';
                            if (n < 5) return 'Minimum 5 minutes';
                            if (n > 180) return 'Maximum 180 minutes';
                            return null;
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  order.items.isEmpty
                      ? 'Range: 5 – 180 minutes'
                      : 'Suggested: $maxPrepTime min (based on menu items).  Range: 5–180 min',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Accept Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final prepTime = int.parse(ctrl.text.trim());
            Navigator.pop(ctx);
            onAccept(prepTime);
          },
        ),
      ],
    ),
  );
}
