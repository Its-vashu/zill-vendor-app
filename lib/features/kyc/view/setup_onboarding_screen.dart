import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../models/setup_onboarding_state.dart';
import '../services/setup_onboarding_service.dart';

class SetupOnboardingScreen extends StatefulWidget {
  const SetupOnboardingScreen({super.key});

  @override
  State<SetupOnboardingScreen> createState() => _SetupOnboardingScreenState();
}

class _SetupOnboardingScreenState extends State<SetupOnboardingScreen> {
  late final SetupOnboardingService _service;

  SetupOnboardingState? _state;
  bool _isLoading = true;
  bool _isRedirectingHome = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = SetupOnboardingService(apiService: context.read<ApiService>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
  }

  Future<void> _loadState({bool navigateIfComplete = true}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final nextState = await _service.fetchState();
      if (!mounted) return;

      setState(() {
        _state = nextState;
        _isLoading = false;
      });

      if (navigateIfComplete && nextState.isSetupComplete) {
        await _goToDashboard();
      }
    } on SetupOnboardingException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to refresh setup progress.';
      });
    }
  }

  Future<void> _goToDashboard() async {
    if (!mounted || _isRedirectingHome) return;

    _isRedirectingHome = true;
    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
  }

  Future<void> _openDocuments() async {
    await Navigator.of(context).pushNamed(AppRouter.kycDocuments);
    if (!mounted) return;
    await _loadState();
  }

  Future<void> _openSubscriptionPlans() async {
    if (_state?.isSubscriptionLocked ?? true) {
      return;
    }

    await Navigator.of(context).pushNamed(AppRouter.subscriptionPlans);
    if (!mounted) return;
    await _loadState();
  }

  Future<void> _logout() async {
    await context.read<AuthViewModel>().logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3ED),
              Color(0xFFFDF7F4),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _loadState(navigateIfComplete: false),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                const _HeaderCard(),
                const SizedBox(height: AppSizes.lg),
                if (_isLoading && state == null)
                  const _LoadingCard()
                else if (_errorMessage != null && state == null)
                  _ErrorCard(message: _errorMessage!, onRetry: _loadState)
                else if (state != null) ...[
                  _OnboardingStepCard(
                    stepLabel: 'STEP 1',
                    badgeLabel: state.documentsComplete
                        ? 'DONE'
                        : state.documentsProgressLabel,
                    badgeColor: state.documentsComplete
                        ? AppColors.success
                        : AppColors.primary,
                    badgeBackground: state.documentsComplete
                        ? AppColors.successLight
                        : const Color(0xFFFFF3ED),
                    icon: state.documentsComplete
                        ? Icons.check_circle_rounded
                        : Icons.file_copy_rounded,
                    iconBackground: state.documentsComplete
                        ? AppColors.successLight
                        : const Color(0xFFFFF3ED),
                    iconColor: state.documentsComplete
                        ? AppColors.success
                        : AppColors.primary,
                    title: 'Upload Required Documents',
                    subtitle: state.documentsComplete
                        ? _documentsCompleteSubtitle(state)
                        : 'FSSAI License, PAN Card & Bank Details',
                    buttonLabel: 'Upload Documents',
                    onPressed: _openDocuments,
                  ),
                  const SizedBox(height: AppSizes.md),
                  _OnboardingStepCard(
                    stepLabel: 'STEP 2',
                    badgeLabel: state.subscriptionComplete
                        ? 'DONE'
                        : state.isSubscriptionLocked
                        ? 'LOCKED'
                        : 'REQUIRED',
                    badgeColor: state.subscriptionComplete
                        ? AppColors.success
                        : state.isSubscriptionLocked
                        ? AppColors.textHint
                        : AppColors.primary,
                    badgeBackground: state.subscriptionComplete
                        ? AppColors.successLight
                        : state.isSubscriptionLocked
                        ? const Color(0xFFF1F3F5)
                        : const Color(0xFFFFF3ED),
                    icon: state.subscriptionComplete
                        ? Icons.check_circle_rounded
                        : Icons.workspace_premium_rounded,
                    iconBackground: state.subscriptionComplete
                        ? AppColors.successLight
                        : state.isSubscriptionLocked
                        ? const Color(0xFFF1F3F5)
                        : const Color(0xFFFFF3ED),
                    iconColor: state.subscriptionComplete
                        ? AppColors.success
                        : state.isSubscriptionLocked
                        ? AppColors.textHint
                        : AppColors.primary,
                    title: 'Choose Subscription Plan',
                    subtitle: state.subscriptionComplete
                        ? 'Your subscription is active and ready to go.'
                        : state.isSubscriptionLocked
                        ? 'Unlock this step by uploading all required documents first.'
                        : 'Select a plan to activate your restaurant.',
                    buttonLabel: 'Choose Plan',
                    onPressed: state.isSubscriptionLocked
                        ? null
                        : _openSubscriptionPlans,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  const _InfoFooter(),
                ] else
                  _ErrorCard(
                    message: 'Unable to load setup progress.',
                    onRetry: _loadState,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _documentsCompleteSubtitle(SetupOnboardingState state) {
    switch (state.profileVerificationStatus) {
      case 'approved':
        return 'Your required documents are approved.';
      case 'rejected':
        return 'Documents uploaded. Please review any rejected items.';
      case 'submitted':
        return 'Documents uploaded. Our team is reviewing them now.';
      default:
        return 'All required onboarding documents are uploaded.';
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8F65), AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Complete Your Setup',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Complete these steps to go live and start receiving orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    required this.stepLabel,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeBackground,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String stepLabel;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeBackground;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isEnabled ? 1 : 0.78,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEnabled ? const Color(0xFFFFD6C7) : AppColors.border,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSizes.sm,
                        runSpacing: AppSizes.xs,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              stepLabel,
                              style: const TextStyle(
                                fontSize: AppSizes.fontXs,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: AppSizes.fontXs,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(
                  onPressed == null
                      ? Icons.lock_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(buttonLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: onPressed == null
                      ? const Color(0xFFE2E5E8)
                      : AppColors.primary,
                  foregroundColor: onPressed == null
                      ? AppColors.textSecondary
                      : Colors.white,
                  textStyle: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _InfoFooter extends StatelessWidget {
  const _InfoFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Your restaurant will go live after completing both steps',
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: AppSizes.md),
          Text(
            'Checking your setup progress...',
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function({bool navigateIfComplete}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.errorLight),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppSizes.fontLg,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton(
            onPressed: () {
              onRetry(navigateIfComplete: false);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
