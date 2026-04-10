class SetupOnboardingState {
  const SetupOnboardingState({
    required this.uploadedRequiredDocuments,
    required this.totalRequiredDocuments,
    required this.documentsComplete,
    required this.subscriptionComplete,
    this.hasSubscription = false,
    this.subscriptionStatus,
    this.profileVerificationStatus,
    this.isProfileVerified,
  });

  final int uploadedRequiredDocuments;
  final int totalRequiredDocuments;
  final bool documentsComplete;
  final bool subscriptionComplete;
  final bool hasSubscription;
  final String? subscriptionStatus;
  final String? profileVerificationStatus;
  final bool? isProfileVerified;

  bool get isSetupComplete => documentsComplete && subscriptionComplete;

  bool get isSubscriptionLocked => !documentsComplete;

  String get documentsProgressLabel =>
      '$uploadedRequiredDocuments/$totalRequiredDocuments uploaded';
}
