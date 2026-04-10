// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// ─────────────────────────────────────────
//
// Mirrors backend `VendorProfile.VERIFICATION_STATUS` choices
// and the computed status returned by `GET /api/vendors/profile/`,
// which is derived from `VendorDocument` rows in
// `food-delivery-api/vendors/views.py:532-556`.
//
// Web counterpart: `frontend_pages/vendor/dashboard.html` —
// the `statusConfig` map at the `updateVerificationBanner()` callsite.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum VerificationStatus {
  /// No documents uploaded yet — vendor must upload to start verification.
  pending,

  /// All required documents uploaded, awaiting admin review (24-48 hrs).
  submitted,

  /// Admin has begun reviewing documents.
  underReview,

  /// All required documents verified — vendor can accept orders.
  approved,

  /// One or more documents rejected — vendor must re-upload.
  rejected;

  static VerificationStatus fromApi(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'submitted':
        return VerificationStatus.submitted;
      case 'under_review':
        return VerificationStatus.underReview;
      case 'approved':
      case 'verified':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'pending':
      default:
        return VerificationStatus.pending;
    }
  }

  /// Short label used on profile badge chips.
  String get badgeLabel {
    switch (this) {
      case VerificationStatus.pending:
        return 'Unverified';
      case VerificationStatus.submitted:
        return 'Under Review';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  /// Banner title — matches the web `statusConfig.title` strings 1:1.
  String get bannerTitle {
    switch (this) {
      case VerificationStatus.pending:
        return 'Documents Required';
      case VerificationStatus.submitted:
        return 'Verification In Progress';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Verification Failed';
    }
  }

  /// Banner subtitle — matches the web `statusConfig.message` strings 1:1.
  String get bannerMessage {
    switch (this) {
      case VerificationStatus.pending:
        return 'Upload your documents to start accepting orders.';
      case VerificationStatus.submitted:
        return 'Your documents are being reviewed (24-48 hours).';
      case VerificationStatus.underReview:
        return 'Our team is reviewing your documents.';
      case VerificationStatus.approved:
        return 'Your account is fully verified.';
      case VerificationStatus.rejected:
        return 'Some documents were rejected. Please re-upload.';
    }
  }

  Color get accentColor {
    switch (this) {
      case VerificationStatus.pending:
        return AppColors.error;
      case VerificationStatus.submitted:
        return AppColors.info;
      case VerificationStatus.underReview:
        return AppColors.warning;
      case VerificationStatus.approved:
        return AppColors.success;
      case VerificationStatus.rejected:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case VerificationStatus.pending:
        return Icons.upload_file_rounded;
      case VerificationStatus.submitted:
        return Icons.hourglass_top_rounded;
      case VerificationStatus.underReview:
        return Icons.search_rounded;
      case VerificationStatus.approved:
        return Icons.verified_rounded;
      case VerificationStatus.rejected:
        return Icons.error_outline_rounded;
    }
  }

  bool get isApproved => this == VerificationStatus.approved;

  /// True when the vendor has submitted documents and is waiting on admin.
  bool get isInReview =>
      this == VerificationStatus.submitted ||
      this == VerificationStatus.underReview;

  /// True when the dashboard banner should be hidden — only when fully approved.
  /// Mirrors `dashboard.html:1768`.
  bool get hideBanner => this == VerificationStatus.approved;
}
