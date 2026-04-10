import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/models/verification_status.dart';

/// Verification banner that mirrors the web `dashboard.html` `statusConfig`
/// state machine 1:1 — pending / submitted / under_review / rejected.
/// Caller is responsible for hiding the widget when status is `approved`.
class KycWarningBanner extends StatelessWidget {
  final VerificationStatus status;
  final VoidCallback onTap;

  const KycWarningBanner({
    super.key,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = status.accentColor;
    final theme = _themeFor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withAlpha(140), width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(status.icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.bannerTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.bannerMessage,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: theme.textColor.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: theme.textColor,
            ),
          ],
        ),
      ),
    );
  }

  _BannerTheme _themeFor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return _BannerTheme(
          gradient: const [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          textColor: const Color(0xFFB71C1C),
        );
      case VerificationStatus.submitted:
        return _BannerTheme(
          gradient: const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          textColor: const Color(0xFF0D47A1),
        );
      case VerificationStatus.underReview:
        return _BannerTheme(
          gradient: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          textColor: AppColors.deepOrange,
        );
      case VerificationStatus.rejected:
        return _BannerTheme(
          gradient: const [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          textColor: const Color(0xFFB71C1C),
        );
      case VerificationStatus.approved:
        return _BannerTheme(
          gradient: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          textColor: const Color(0xFF1B5E20),
        );
    }
  }
}

class _BannerTheme {
  final List<Color> gradient;
  final Color textColor;
  const _BannerTheme({required this.gradient, required this.textColor});
}
