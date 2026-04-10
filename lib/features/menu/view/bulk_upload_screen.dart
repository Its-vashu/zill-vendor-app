// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/bulk_upload_viewmodel.dart';

// ────────────────────────────────────────────────────────────────────
//  Entry point — creates ViewModel and injects ApiService
// ────────────────────────────────────────────────────────────────────
class BulkUploadScreen extends StatelessWidget {
  const BulkUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BulkUploadViewModel(
        apiService: context.read<ApiService>(),
      ),
      child: const _BulkUploadBody(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Tabbed scaffold — CSV / Photos / Menu Photo
//  Mirrors the web Bulk Menu Upload page but only includes the three
//  tabs that make sense on mobile (CSV file, multi-image upload from
//  gallery, OCR from a printed menu card).
// ────────────────────────────────────────────────────────────────────
class _BulkUploadBody extends StatelessWidget {
  const _BulkUploadBody();

  // ── Clear-existing confirmation dialog ──────────────────────────────
  // Shows a dialog requiring the user to press "Confirm Delete" before
  // the upload proceeds when clearExisting is enabled.
  Future<bool> _confirmClearExisting(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clear Entire Menu?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'You have enabled "Clear existing menu". This will permanently '
          'delete ALL your current menu items and categories before the '
          'import runs.\n\nThis action cannot be undone.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Confirm Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Upload tap handler (guards clearExisting with dialog) ───────────
  Future<void> _handleUploadTap(
      BuildContext context, BulkUploadViewModel vm) async {
    if (!vm.canUpload) return;

    if (vm.clearExisting) {
      final confirmed = await _confirmClearExisting(context);
      if (!confirmed) return;
    }

    await vm.uploadMenu();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Bulk Menu Upload',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.description_rounded, size: 20),
                text: 'CSV',
                height: 56,
              ),
              Tab(
                icon: Icon(Icons.photo_library_rounded, size: 20),
                text: 'Photos',
                height: 56,
              ),
              Tab(
                icon: Icon(Icons.camera_alt_rounded, size: 20),
                text: 'Menu Photo',
                height: 56,
              ),
            ],
          ),
        ),
        body: Consumer<BulkUploadViewModel>(
          builder: (context, vm, _) {
            // ── Global error snackbar (shared across all tabs) ────
            if (vm.errorMessage != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(vm.errorMessage!),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'Dismiss',
                        textColor: Colors.white,
                        onPressed: vm.clearError,
                      ),
                    ),
                  );
                vm.clearError();
              });
            }

            return SafeArea(
              child: TabBarView(
                children: [
                  _CsvUploadTab(
                    vm: vm,
                    onUploadTap: () => _handleUploadTap(context, vm),
                  ),
                  _BulkImagesTab(vm: vm),
                  _MenuPhotoTab(vm: vm),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Tab 1 — CSV Upload (the existing flow, just extracted into a widget)
// ────────────────────────────────────────────────────────────────────
class _CsvUploadTab extends StatelessWidget {
  final BulkUploadViewModel vm;
  final VoidCallback onUploadTap;

  const _CsvUploadTab({required this.vm, required this.onUploadTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Instructions + Template ──────────────────────────
          _InstructionsCard(vm: vm),
          const SizedBox(height: 16),

          // ── File Selection ───────────────────────────────────
          _FilePickerCard(vm: vm),
          const SizedBox(height: 16),

          // ── Upload Options ───────────────────────────────────
          _OptionsCard(vm: vm),
          const SizedBox(height: 24),

          // ── Upload Button ────────────────────────────────────
          _UploadButton(vm: vm, onTap: onUploadTap),

          // ── Upload Progress ──────────────────────────────────
          if (vm.isLoading && vm.uploadProgress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vm.uploadProgress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(vm.uploadProgress * 100).toStringAsFixed(0)}% uploaded',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],

          // ── Result Summary ───────────────────────────────────
          if (vm.uploadResult != null) ...[
            const SizedBox(height: 20),
            _ResultSummaryCard(result: vm.uploadResult!),
          ],

          // ── Auto-fetch images quick action ──────────────────
          // Lets the vendor trigger Unsplash auto-fetch for items
          // that already exist in the menu (independent of CSV
          // upload). Hidden while a CSV upload is in flight.
          if (!vm.isLoading) ...[
            const SizedBox(height: 24),
            _AutoFetchCard(vm: vm),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Instructions Card
// ────────────────────────────────────────────────────────────────────
class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.vm});

  final BulkUploadViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.infoLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.info.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'How it works',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _InstructionStep(
              number: '1',
              text: 'Download the CSV template below.',
            ),
            const SizedBox(height: 6),
            const _InstructionStep(
              number: '2',
              text: 'Fill in your menu items following the column format.',
            ),
            const SizedBox(height: 6),
            const _InstructionStep(
              number: '3',
              text: 'Upload the completed CSV and review the results.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: vm.isLoading ? null : vm.downloadTemplate,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download CSV Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.info.withAlpha(120),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  File Picker Card
// ────────────────────────────────────────────────────────────────────
class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.vm});

  final BulkUploadViewModel vm;

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final file = vm.selectedFile;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              file != null ? AppColors.success.withAlpha(80) : AppColors.border,
          width: file != null ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: vm.isLoading ? null : vm.pickFile,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              file == null ? _buildEmptyState() : _buildSelectedState(file),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.upload_file_rounded,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Tap to select a CSV file',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Only .csv files · Max 5 MB',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildSelectedState(dynamic file) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name as String,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((file.size as int) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatFileSize(file.size as int),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: vm.isLoading ? null : vm.clearFile,
          icon: const Icon(Icons.close_rounded),
          iconSize: 20,
          color: AppColors.textSecondary,
          tooltip: 'Remove file',
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Upload Options Card
// ────────────────────────────────────────────────────────────────────
class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.vm});

  final BulkUploadViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Upload Options',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // ── Clear existing (danger toggle) ─────────────────────
            SwitchListTile(
              title: Row(
                children: [
                  const Text(
                    'Clear existing menu',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (vm.clearExisting) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DANGER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: const Text(
                'Delete all current items before import',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              value: vm.clearExisting,
              onChanged: vm.isLoading ? null : vm.toggleClearExisting,
              activeTrackColor: AppColors.error,
              dense: true,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              title: const Text(
                'Update existing items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Overwrite items that match by name',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              value: vm.updateExisting,
              onChanged: vm.isLoading ? null : vm.toggleUpdateExisting,
              activeTrackColor: AppColors.primary,
              dense: true,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              title: const Text(
                'Auto-fetch images',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Download images from URLs in the CSV',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              value: vm.autoFetchImages,
              onChanged: vm.isLoading ? null : vm.toggleAutoFetchImages,
              activeTrackColor: AppColors.primary,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Upload Button
// ────────────────────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.vm, required this.onTap});

  final BulkUploadViewModel vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        // Use the parent-provided handler so the dialog can intercept.
        onPressed: vm.canUpload ? onTap : null,
        icon: vm.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload_rounded, size: 22),
        label: Text(vm.isLoading ? 'Uploading…' : 'Upload Menu'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(100),
          disabledForegroundColor: Colors.white60,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Result Summary Card  (Fix 3 · 4 · 5 · 6)
// ────────────────────────────────────────────────────────────────────
class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    // ── Parse all backend fields ──────────────────────────────────────
    //
    // Backend response shape (from /vendors/menu-items/bulk-upload-csv/):
    //   {
    //     "success": true,
    //     "message": "...",
    //     "summary": { categories_created, items_created, items_updated,
    //                  items_skipped, errors[], total_items_now,
    //                  total_categories_now },
    //     "created_items": [{ id, name, category, price }, ...],
    //     "parse_warnings": [...],
    //     "auto_images": { images_assigned, skipped, failed }
    //   }
    //
    // Counts are nested inside `summary`, NOT at the top level. Reading
    // them at top-level (the previous bug) made every card show "0".
    final summary =
        (result['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final categoriesCreated = summary['categories_created'] ?? 0;
    final itemsCreated = summary['items_created'] ?? 0;
    final itemsUpdated = summary['items_updated'] ?? 0;
    final itemsSkipped = summary['items_skipped'] ?? 0;
    final totalItemsNow = summary['total_items_now'];
    final totalCategoriesNow = summary['total_categories_now'];

    // auto_images is the wrapper for Unsplash auto-fetch results.
    final autoImages = result['auto_images'] as Map<String, dynamic>?;
    final imagesFetched = autoImages?['images_assigned'];
    final imagesSkipped = autoImages?['skipped'];
    final imagesFailed = autoImages?['failed'];

    // parse_warnings is the only list that lives at top-level.
    final warnings = (result['parse_warnings'] as List<dynamic>?)
            ?.map((w) => w.toString())
            .toList() ??
        const <String>[];

    // Row-level errors live inside summary.errors.
    final errors = (summary['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    // created_items: list of {id, name, category, price} for newly
    // created rows. Shown to the vendor as a confirmation list.
    final createdItems = (result['created_items'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];

    final hasIssues = errors.isNotEmpty || warnings.isNotEmpty;

    return Card(
      elevation: 0,
      color: hasIssues ? AppColors.warningLight : AppColors.successLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasIssues
              ? AppColors.warning.withAlpha(60)
              : AppColors.success.withAlpha(60),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  hasIssues
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: hasIssues ? AppColors.warning : AppColors.success,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasIssues
                        ? 'Upload completed with warnings'
                        : 'Upload Successful!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: hasIssues ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Fix 4 + 5 — Stat chips grid ───────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatChip(
                  label: 'Categories\nCreated',
                  value: '$categoriesCreated',
                  color: AppColors.info,
                ),
                _StatChip(
                  label: 'Items\nCreated',
                  value: '$itemsCreated',
                  color: AppColors.success,
                ),
                _StatChip(
                  label: 'Items\nUpdated',
                  value: '$itemsUpdated',
                  color: AppColors.primary,
                ),
                _StatChip(
                  label: 'Items\nSkipped',
                  value: '$itemsSkipped',
                  color: AppColors.textSecondary,
                ),
                // Fix 4 — total_items_now
                if (totalItemsNow != null)
                  _StatChip(
                    label: 'Total Items\nNow',
                    value: '$totalItemsNow',
                    color: AppColors.teal,
                  ),
                // Fix 4 — total_categories_now
                if (totalCategoriesNow != null)
                  _StatChip(
                    label: 'Total Categories\nNow',
                    value: '$totalCategoriesNow',
                    color: AppColors.purple,
                  ),
                // auto_images.images_assigned (was wrongly read from
                // top-level result['images_fetched'] before).
                if (imagesFetched != null)
                  _StatChip(
                    label: 'Images\nFetched',
                    value: '$imagesFetched',
                    color: AppColors.amber,
                  ),
                if (imagesSkipped != null && imagesSkipped != 0)
                  _StatChip(
                    label: 'Images\nSkipped',
                    value: '$imagesSkipped',
                    color: AppColors.textSecondary,
                  ),
                if (imagesFailed != null && imagesFailed != 0)
                  _StatChip(
                    label: 'Images\nFailed',
                    value: '$imagesFailed',
                    color: AppColors.error,
                  ),
              ],
            ),

            // ── Created items list ────────────────────────────────
            // Backend returns created_items: [{id, name, category, price}].
            // Show them so the vendor can confirm exactly what landed.
            if (createdItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: createdItems.length <= 5,
                shape: const Border(),
                leading: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
                title: Text(
                  '${createdItems.length} new '
                  'item${createdItems.length == 1 ? '' : 's'} created',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: Scrollbar(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: createdItems.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.borderLight,
                        ),
                        itemBuilder: (_, i) {
                          final item = createdItems[i];
                          final name = item['name']?.toString() ?? '';
                          final category =
                              item['category']?.toString() ?? '';
                          final price = item['price'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.success.withAlpha(28),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (category.isNotEmpty)
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (price != null)
                                  Text(
                                    '\u20B9$price',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Fix 3 — parse_warnings section ────────────────────
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: warnings.length <= 5,
                shape: const Border(),
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                title: Text(
                  '${warnings.length} parse warning${warnings.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: warnings.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warnings[i],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Row errors (summary.errors) ───────────────────────
            // Scrollable red list capped at 240px so the card stays
            // usable even when the CSV had 50+ bad rows.
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: errors.length <= 5,
                shape: const Border(),
                leading: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                title: Text(
                  '${errors.length} row error${errors.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                subtitle: const Text(
                  'These rows were not imported. Fix them in your CSV '
                  'and re-upload.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withAlpha(50),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: Scrollbar(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        itemCount: errors.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: AppColors.error.withAlpha(40),
                        ),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 15,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errors[i],
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Fix 6 — "Back to Menu" button ─────────────────────
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Menu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side:
                      BorderSide(color: AppColors.success.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TAB 2 — BULK IMAGES
//  Pick multiple photos from gallery → backend auto-matches each
//  filename to an existing menu item ("butter_chicken.jpg" → "Butter
//  Chicken"). Cap: 50 MB total.
// ════════════════════════════════════════════════════════════════════

class _BulkImagesTab extends StatelessWidget {
  final BulkUploadViewModel vm;
  const _BulkImagesTab({required this.vm});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info card ───────────────────────────────────────
          _InfoBanner(
            icon: Icons.lightbulb_outline_rounded,
            title: 'How it works',
            messages: const [
              'Pick photos from your phone gallery — one per dish.',
              'Name each photo like the menu item '
                  '(e.g. "butter_chicken.jpg" matches "Butter Chicken").',
              'We auto-attach the photo to the matching item.',
              'Max 50 MB total · jpg, png, webp supported.',
            ],
          ),
          const SizedBox(height: 16),

          // ── Pick button ─────────────────────────────────────
          _PrimaryActionButton(
            icon: Icons.add_photo_alternate_rounded,
            label: vm.selectedImages.isEmpty
                ? 'Select Photos'
                : 'Add More Photos',
            onTap: vm.isImagesUploading ? null : vm.pickImages,
          ),

          // ── Picked images grid ──────────────────────────────
          if (vm.selectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${vm.selectedImages.length} '
                        'photo${vm.selectedImages.length == 1 ? '' : 's'} '
                        'selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatBytes(vm.selectedImagesTotalBytes),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: vm.isImagesUploading ? null : vm.clearImages,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: vm.selectedImages.length,
                    itemBuilder: (_, i) {
                      final img = vm.selectedImages[i];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(img.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.borderLight,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: vm.isImagesUploading
                                  ? null
                                  : () => vm.removeImageAt(i),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              color: Colors.black54,
                              child: Text(
                                img.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Upload button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: vm.canUploadImages ? vm.uploadImages : null,
              icon: vm.isImagesUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 22),
              label: Text(
                vm.isImagesUploading
                    ? 'Uploading photos…'
                    : 'Upload & Auto-Match',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withAlpha(100),
                disabledForegroundColor: Colors.white60,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // ── Live progress ───────────────────────────────────
          if (vm.isImagesUploading && vm.imagesProgress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vm.imagesProgress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(vm.imagesProgress * 100).toStringAsFixed(0)}% uploaded',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],

          // ── Result card ─────────────────────────────────────
          if (vm.imagesResult != null) ...[
            const SizedBox(height: 20),
            _BulkImagesResultCard(result: vm.imagesResult!),
          ],
        ],
      ),
    );
  }
}

class _BulkImagesResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _BulkImagesResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final summary = (result['summary'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final assigned = summary['images_assigned'] ?? 0;
    final uploaded = summary['images_uploaded'] ?? 0;
    final skipped = summary['images_skipped'] ?? 0;
    final errors = (summary['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final hasIssues = errors.isNotEmpty;

    return Card(
      elevation: 0,
      color: hasIssues ? AppColors.warningLight : AppColors.successLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasIssues
              ? AppColors.warning.withAlpha(60)
              : AppColors.success.withAlpha(60),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasIssues
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: hasIssues ? AppColors.warning : AppColors.success,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasIssues
                        ? 'Photos uploaded with some issues'
                        : 'All photos assigned!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color:
                          hasIssues ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatChip(
                  label: 'Assigned',
                  value: '$assigned',
                  color: AppColors.success,
                ),
                _StatChip(
                  label: 'Uploaded',
                  value: '$uploaded',
                  color: AppColors.info,
                ),
                _StatChip(
                  label: 'Skipped',
                  value: '$skipped',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(50)),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.error.withAlpha(40),
                    ),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errors[i],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TAB 3 — MENU PHOTO OCR
//  Single camera/gallery photo of a printed menu card → backend OCR
//  extracts categories + items → user reviews → confirm to save.
// ════════════════════════════════════════════════════════════════════

class _MenuPhotoTab extends StatelessWidget {
  final BulkUploadViewModel vm;
  const _MenuPhotoTab({required this.vm});

  Future<void> _pickFromCamera() => vm.pickMenuPhoto(source: ImageSource.camera);
  Future<void> _pickFromGallery() =>
      vm.pickMenuPhoto(source: ImageSource.gallery);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info banner ─────────────────────────────────────
          _InfoBanner(
            icon: Icons.auto_awesome_rounded,
            title: 'Magic menu import',
            messages: const [
              'Take a clear photo of your printed menu card.',
              'We use OCR to extract item names and prices.',
              'Review the extracted items, then save to your menu.',
              'Best results: well-lit, flat menu, no glare.',
            ],
          ),
          const SizedBox(height: 16),

          // ── Picker buttons ──────────────────────────────────
          if (vm.menuPhoto == null) ...[
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: vm.isOcrLoading ? null : _pickFromCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PrimaryActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: vm.isOcrLoading ? null : _pickFromGallery,
                  ),
                ),
              ],
            ),
          ] else ...[
            // ── Photo preview ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                color: AppColors.surface,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(vm.menuPhoto!.path),
                      fit: BoxFit.contain,
                      height: 220,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed:
                              vm.isOcrLoading ? null : vm.clearMenuPhoto,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Re-take'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: vm.canRunOcr ? vm.previewMenuPhoto : null,
                          icon: vm.isOcrLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            vm.isOcrLoading ? 'Reading…' : 'Extract Menu',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── OCR loading hint ────────────────────────────────
          if (vm.isOcrLoading) ...[
            const SizedBox(height: 12),
            const Text(
              'OCR can take 15-30 seconds. Please don\'t close the screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // ── Preview / extracted items ───────────────────────
          if (vm.ocrPreview != null) ...[
            const SizedBox(height: 20),
            _OcrPreviewCard(vm: vm),
          ],

          // ── Final result after save ─────────────────────────
          if (vm.ocrResult != null) ...[
            const SizedBox(height: 20),
            _ResultSummaryCard(result: vm.ocrResult!),
          ],
        ],
      ),
    );
  }
}

class _OcrPreviewCard extends StatelessWidget {
  final BulkUploadViewModel vm;
  const _OcrPreviewCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final preview = vm.ocrPreview!;
    final extracted =
        (preview['extracted_data'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final categories =
        (extracted['categories'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
    final totalItems = extracted['total_items'] ?? 0;
    final totalCategories = extracted['total_categories'] ?? 0;

    return Card(
      elevation: 0,
      color: AppColors.infoLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.info.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.preview_rounded,
                  color: AppColors.info,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Extracted $totalItems item'
                    '${totalItems == 1 ? '' : 's'} from '
                    '$totalCategories categor'
                    '${totalCategories == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Review the extracted items below. Tap "Save to Menu" '
              'to add them to your restaurant.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cat in categories) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Text(
                            (cat['name'] ?? '').toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.info,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        ...((cat['items'] as List<dynamic>?) ?? const [])
                            .whereType<Map<String, dynamic>>()
                            .map(
                              (item) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.info.withAlpha(40),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (item['name'] ?? '').toString(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (item['price'] != null)
                                      Text(
                                        '\u20B9${item['price']}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: vm.isOcrLoading ? null : vm.saveMenuPhoto,
                icon: vm.isOcrLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  vm.isOcrLoading ? 'Saving…' : 'Save to Menu',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  AUTO-FETCH IMAGES quick action card
//  POST /vendors/menu-items/auto-fetch-images/  (empty body = all
//  items without an image). Shown at the bottom of the CSV tab.
// ════════════════════════════════════════════════════════════════════

class _AutoFetchCard extends StatelessWidget {
  final BulkUploadViewModel vm;
  const _AutoFetchCard({required this.vm});

  Future<void> _confirmAndRun(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Auto-fetch images?'),
        content: const Text(
          'We\'ll fetch one Unsplash image for every menu item that '
          'currently has no image. This may take a few seconds.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (result == true) {
      await vm.triggerAutoFetchImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = vm.autoFetchResult;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-fetch images',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'For existing items without a photo',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: vm.isAutoFetching
                    ? null
                    : () => _confirmAndRun(context),
                icon: vm.isAutoFetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.amber,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  vm.isAutoFetching ? 'Fetching…' : 'Run auto-fetch',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  side: BorderSide(color: AppColors.amber.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${result['images_assigned'] ?? 0} assigned · '
                        '${result['skipped'] ?? 0} skipped · '
                        '${result['failed'] ?? 0} failed',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: vm.clearAutoFetchResult,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Shared building blocks
// ════════════════════════════════════════════════════════════════════

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> messages;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(30),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final msg in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 4,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(100),
          disabledForegroundColor: Colors.white60,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Stat Chip widget
// ────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
