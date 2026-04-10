import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/kyc_document.dart';
import '../viewmodel/kyc_viewmodel.dart';

class KycDocumentsScreen extends StatefulWidget {
  const KycDocumentsScreen({super.key});

  @override
  State<KycDocumentsScreen> createState() => _KycDocumentsScreenState();
}

class _KycDocumentsScreenState extends State<KycDocumentsScreen> {
  static const _requiredTypes = [
    KycDocumentType.fssai,
    KycDocumentType.pan,
    KycDocumentType.gst,
    KycDocumentType.bank,
  ];

  static const _optionalTypes = [
    KycDocumentType.shopLicense,
    KycDocumentType.ownerId,
    KycDocumentType.other,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KycViewModel>().fetchDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<KycViewModel, bool>(
      selector: (_, vm) => vm.isAnyUploading,
      builder: (context, uploading, child) => PopScope(
        canPop: !uploading,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Please wait for the document upload to finish.',
                ),
                backgroundColor: AppColors.warning,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Documents / KYC'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0.5,
          ),
          body: Consumer<KycViewModel>(
            builder: (context, vm, _) {
              if (vm.status == KycStatus.loading && vm.documents.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (vm.status == KycStatus.error && vm.documents.isEmpty) {
                return _ErrorView(
                  message: vm.error ?? 'Something went wrong',
                  onRetry: vm.fetchDocuments,
                );
              }
              return RefreshIndicator(
                onRefresh: vm.fetchDocuments,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.md),
                  children: [
                    // Verification summary card
                    if (vm.verificationStatus != null)
                      _VerificationSummaryCard(viewModel: vm),
                    const SizedBox(height: AppSizes.md),

                    // ── Info banner (mirrors the blue notice on the web) ──
                    const _KycInfoBanner(),
                    const SizedBox(height: AppSizes.md),

                    // ── Required Documents ──
                    const _SectionHeader(
                      title: 'Required Documents',
                      subtitle:
                          'These documents are mandatory for verification',
                    ),
                    const SizedBox(height: AppSizes.sm),
                    ..._requiredTypes.map((type) => _buildDocCard(vm, type)),

                    const SizedBox(height: AppSizes.lg),

                    // ── Optional Documents ──
                    const _SectionHeader(
                      title: 'Optional Documents',
                      subtitle: 'Upload these for faster verification',
                    ),
                    const SizedBox(height: AppSizes.sm),
                    ..._optionalTypes.map((type) => _buildDocCard(vm, type)),

                    const SizedBox(height: AppSizes.xl),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(KycViewModel vm, KycDocumentType type) {
    final doc = vm.documentFor(type);
    final uploadProgress = vm.uploadProgressFor(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: _DocumentCard(
        documentType: type,
        document: doc,
        uploadProgress: uploadProgress,
        onUpload: () => _showUploadSheet(context, type, doc),
        onView: doc?.fileUrl != null ? () => _viewDocument(doc!) : null,
        onDelete: doc != null ? () => _confirmDelete(context, vm, doc) : null,
      ),
    );
  }

  Future<void> _viewDocument(KycDocument doc) async {
    var url = doc.fileUrl;
    if (url == null || url.isEmpty) return;

    // If relative path, prepend the domain
    if (url.startsWith('/')) {
      url = 'https://zill.co.in$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open document'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, KycViewModel vm, KycDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete ${doc.documentTypeDisplay.isNotEmpty ? doc.documentTypeDisplay : doc.documentType.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await vm.deleteDocument(doc.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Document deleted'
                          : vm.error ?? 'Delete failed',
                    ),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadSheet(
    BuildContext context,
    KycDocumentType type,
    KycDocument? existing,
  ) {
    final numberController = TextEditingController(
      text: existing?.documentNumber ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSizes.lg,
            right: AppSizes.lg,
            top: AppSizes.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  existing != null
                      ? 'Re-upload ${type.displayName}'
                      : 'Upload ${type.displayName}',
                  style: const TextStyle(
                    fontSize: AppSizes.fontXl,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  type.description,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Document number field
                TextFormField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: '${type.displayName} Number',
                    hintText: 'Enter document number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.lg),
                // Source buttons
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'camera',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'gallery',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'pdf',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Center(
                  child: Text(
                    'Max file size: 5 MB',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleFilePick(
    BuildContext parentContext,
    BuildContext sheetContext,
    KycDocumentType type,
    TextEditingController numberController,
    GlobalKey<FormState> formKey,
    String source,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final vm = parentContext.read<KycViewModel>();
    String? filePath;

    try {
      if (source == 'camera') {
        filePath = await vm.pickFromCamera();
      } else if (source == 'gallery') {
        filePath = await vm.pickFromGallery();
      } else {
        filePath = await vm.pickPdf();
      }
    } on PickerPermissionDeniedException {
      // Permission permanently denied — guide user to app settings
      if (sheetContext.mounted) {
        final label = source == 'camera' ? 'Camera' : 'Photos';
        _showPermissionDeniedDialog(sheetContext, label);
      }
      return;
    }

    // User cancelled (pressed back without selecting)
    if (filePath == null) return;

    // Close the bottom sheet
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }

    // Start upload with progress
    final success = await vm.uploadDocument(
      type: type,
      documentNumber: numberController.text.trim(),
      filePath: filePath,
    );

    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${type.displayName} uploaded successfully'
                : vm.error ?? 'Upload failed',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      );
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: Text('$permission Permission Required'),
        content: Text(
          '$permission access has been permanently denied. '
          'Please enable it from your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// White verification status card mirroring the web KYC page header.
/// Title on the left, status pill on the right, gradient progress bar
/// underneath, and a single-line subtitle explaining the count.
class _VerificationSummaryCard extends StatelessWidget {
  final KycViewModel viewModel;

  const _VerificationSummaryCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final status = viewModel.verificationStatus!;
    final progress = viewModel.requiredDocumentsUploadProgress;
    final uploaded = viewModel.uploadedRequiredDocumentCount;
    final total = viewModel.totalRequiredDocumentCount;

    final _SummaryTone tone = _toneFor(status, uploaded, total);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verification Status',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(label: tone.label, color: tone.pillColor),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(tone.barColor),
            ),
          ),
          const SizedBox(height: AppSizes.xs + 2),
          Text(
            tone.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontSm,
            ),
          ),
        ],
      ),
    );
  }

  _SummaryTone _toneFor(
    KycVerificationStatus status,
    int uploaded,
    int total,
  ) {
    if (status.isFullyVerified) {
      return const _SummaryTone(
        label: 'Verified',
        pillColor: AppColors.success,
        barColor: AppColors.success,
        subtitle: 'All documents verified',
      );
    }
    if (uploaded == 0) {
      return _SummaryTone(
        label: 'Pending',
        pillColor: AppColors.error,
        barColor: AppColors.error,
        subtitle: '$uploaded of $total required documents uploaded',
      );
    }
    if (uploaded < total) {
      return _SummaryTone(
        label: 'In Progress',
        pillColor: AppColors.warning,
        barColor: AppColors.warning,
        subtitle: '$uploaded of $total required documents uploaded',
      );
    }
    return _SummaryTone(
      label: 'Under Review',
      pillColor: AppColors.info,
      barColor: AppColors.info,
      subtitle: '$total documents under review',
    );
  }
}

class _SummaryTone {
  final String label;
  final Color pillColor;
  final Color barColor;
  final String subtitle;
  const _SummaryTone({
    required this.label,
    required this.pillColor,
    required this.barColor,
    required this.subtitle,
  });
}

/// Light info banner shown below the verification card on the KYC page.
/// Mirrors the blue info row on the web KYC layout.
class _KycInfoBanner extends StatelessWidget {
  const _KycInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.info.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Upload all required documents for verification. Your '
              'restaurant will be activated once all documents are '
              'verified by our team.',
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.info.withAlpha(220),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled rounded pill — used for both the summary card and individual
/// document cards. Soft tinted background + bold colored label.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final KycDocumentType documentType;
  final KycDocument? document;
  final UploadProgress? uploadProgress;
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  const _DocumentCard({
    required this.documentType,
    this.document,
    this.uploadProgress,
    required this.onUpload,
    this.onView,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = document != null;
    final isUploading = uploadProgress?.isUploading ?? false;
    final isRejected = document?.isRejected == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        // Border stays neutral except for rejected documents — matches the
        // soft "all-cards-look-the-same" aesthetic of the web layout.
        border: Border.all(
          color: isRejected ? AppColors.error : AppColors.border,
          width: isRejected ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document icon — neutral tinted square; no status colour.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _iconData,
                    color: AppColors.primary,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentType.displayName,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        documentType.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppSizes.fontXs + 1,
                          color: AppColors.textHint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                // Top-right pill — status if uploaded, "Upload" CTA otherwise.
                if (isUploading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else if (isRejected)
                  _ReUploadPillButton(onTap: onUpload)
                else if (isUploaded)
                  _StatusPill(
                    label: _statusLabel(document!.status),
                    color: _statusColor(document!.status),
                  )
                else
                  _UploadPillButton(onTap: onUpload),
              ],
            ),
          ),

          // ── Uploaded file info row with View / Delete ──
          if (isUploaded && !isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFilePdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      size: 20,
                      color: _isFilePdf ? AppColors.error : AppColors.primary,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (document!.documentNumber.isNotEmpty)
                            Text(
                              'No: ${document!.documentNumber}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (document!.expiryDate != null)
                            Text(
                              'Expires: ${_formatDate(document!.expiryDate!)}',
                              style: TextStyle(
                                fontSize: AppSizes.fontXs,
                                color: document!.isExpired
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          if (document!.documentNumber.isEmpty &&
                              document!.expiryDate == null)
                            const Text(
                              'Uploaded',
                              style: TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // View button
                    if (onView != null)
                      _IconActionButton(
                        icon: Icons.visibility_rounded,
                        color: AppColors.primary,
                        tooltip: 'View',
                        onTap: onView!,
                      ),
                    // Delete button
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      _IconActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        tooltip: 'Delete',
                        onTap: onDelete!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Rejection reason
          if (document?.isRejected == true &&
              document!.rejectionReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        document!.rejectionReason,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Upload progress bar
          if (isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    child: LinearProgressIndicator(
                      value: uploadProgress?.progress ?? 0.0,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    '${((uploadProgress?.progress ?? 0) * 100).toInt()}% uploading...',
                    style: const TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _isFilePdf {
    final url = document?.fileUrl ?? '';
    return url.toLowerCase().endsWith('.pdf');
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _statusLabel(KycDocStatus status) {
    switch (status) {
      case KycDocStatus.verified:
        return 'Verified';
      case KycDocStatus.rejected:
        return 'Rejected';
      case KycDocStatus.pending:
        return 'Under Review';
    }
  }

  Color _statusColor(KycDocStatus status) {
    switch (status) {
      case KycDocStatus.verified:
        return AppColors.success;
      case KycDocStatus.rejected:
        return AppColors.error;
      case KycDocStatus.pending:
        return AppColors.info;
    }
  }

  IconData get _iconData {
    switch (documentType) {
      case KycDocumentType.fssai:
        return Icons.restaurant_menu_rounded;
      case KycDocumentType.gst:
        return Icons.receipt_long_rounded;
      case KycDocumentType.pan:
        return Icons.credit_card_rounded;
      case KycDocumentType.bank:
        return Icons.account_balance_rounded;
      case KycDocumentType.shopLicense:
        return Icons.storefront_rounded;
      case KycDocumentType.ownerId:
        return Icons.badge_rounded;
      case KycDocumentType.other:
        return Icons.description_rounded;
    }
  }
}

/// Filled "Upload" pill — shown on a fresh, never-uploaded document card.
/// Compact rounded button so it sits next to the `_StatusPill` slot.
class _UploadPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Upload',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "Re-Upload" pill — shown on a rejected document card so the
/// re-upload action stays discoverable without bringing back loud red
/// buttons or borders.
class _ReUploadPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReUploadPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Re-Upload',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: AppSizes.iconLg),
            const SizedBox(height: AppSizes.xs),
            Text(
              label,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppSizes.fontLg,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
