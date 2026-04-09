// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/bulk_upload_viewmodel.dart';

// ────────────────────────────────────────────────────────────────────
//  Bulk CSV Upload Screen
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

class _BulkUploadBody extends StatelessWidget {
  const _BulkUploadBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: Consumer<BulkUploadViewModel>(
        builder: (context, vm, _) {
          // ── Show error snackbar ──────────────────────────────────
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Instructions + Template Card ──────────────────
                _InstructionsCard(vm: vm),
                const SizedBox(height: 16),

                // ── File Selection ───────────────────────────────
                _FilePickerCard(vm: vm),
                const SizedBox(height: 16),

                // ── Upload Options ──────────────────────────────
                _OptionsCard(vm: vm),
                const SizedBox(height: 24),

                // ── Upload Button + Progress ────────────────────
                _UploadButton(vm: vm),
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

                // ── Result Summary ──────────────────────────────
                if (vm.uploadResult != null) ...[
                  const SizedBox(height: 20),
                  _ResultSummaryCard(result: vm.uploadResult!),
                ],
              ],
            ),
          );
        },
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
          color: file != null ? AppColors.success.withAlpha(80) : AppColors.border,
          width: file != null ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: vm.isLoading ? null : vm.pickFile,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: file == null
              ? _buildEmptyState()
              : _buildSelectedState(file, context),
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
          'Only .csv files are accepted',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedState(dynamic file, BuildContext context) {
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
                file.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (file.size != null && file.size > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatFileSize(file.size),
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
            SwitchListTile(
              title: const Text(
                'Clear existing menu',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
  const _UploadButton({required this.vm});

  final BulkUploadViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: vm.canUpload ? vm.uploadMenu : null,
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
//  Result Summary Card
// ────────────────────────────────────────────────────────────────────
class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final categoriesCreated = result['categories_created'] ?? 0;
    final itemsCreated = result['items_created'] ?? 0;
    final itemsUpdated = result['items_updated'] ?? 0;
    final itemsSkipped = result['items_skipped'] ?? 0;
    final errors = (result['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Card(
      elevation: 0,
      color: errors.isEmpty ? AppColors.successLight : AppColors.warningLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: errors.isEmpty
              ? AppColors.success.withAlpha(60)
              : AppColors.warning.withAlpha(60),
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
                  errors.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: errors.isEmpty ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errors.isEmpty
                        ? 'Upload Successful!'
                        : 'Upload completed with warnings',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: errors.isEmpty
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stats Grid ──────────────────────────────────────
            Wrap(
              spacing: 12,
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
              ],
            ),

            // ── Row Errors ──────────────────────────────────────
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: errors.length <= 5,
                shape: const Border(),
                title: Text(
                  '${errors.length} row error${errors.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: errors.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errors[i],
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
          ],
        ),
      ),
    );
  }
}

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
