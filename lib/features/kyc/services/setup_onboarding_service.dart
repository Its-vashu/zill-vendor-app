import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/setup_onboarding_state.dart';

class SetupOnboardingException implements Exception {
  const SetupOnboardingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SetupOnboardingService {
  SetupOnboardingService({required ApiService apiService})
    : _apiService = apiService;

  static const Set<String> _requiredDocumentTypes = {'fssai', 'pan', 'bank'};

  final ApiService _apiService;

  Future<SetupOnboardingState> fetchState() async {
    final results = await Future.wait<Map<String, dynamic>?>([
      _safeGetMap(ApiEndpoints.profile, label: 'profile'),
      _safeGetMap(ApiEndpoints.documents, label: 'documents'),
      _safeGetMap(ApiEndpoints.mySubscription, label: 'subscription'),
    ]);

    final profileData = results[0];
    final documentsData = results[1];
    final subscriptionData = results[2];

    if (documentsData == null || subscriptionData == null) {
      throw const SetupOnboardingException(
        'Could not load onboarding status right now.',
      );
    }

    final uploadedRequiredDocuments = _countUploadedRequiredDocuments(
      documentsData,
    );
    final documentsComplete =
        uploadedRequiredDocuments == _requiredDocumentTypes.length;

    final hasSubscription =
        subscriptionData['has_subscription'] == true ||
        subscriptionData['subscription'] is Map<String, dynamic>;
    final subscriptionStatus =
        (subscriptionData['subscription'] as Map<String, dynamic>?)?['status']
            ?.toString();
    final subscriptionComplete =
        hasSubscription &&
        (subscriptionStatus == 'trial' || subscriptionStatus == 'active');

    return SetupOnboardingState(
      uploadedRequiredDocuments: uploadedRequiredDocuments,
      totalRequiredDocuments: _requiredDocumentTypes.length,
      documentsComplete: documentsComplete,
      subscriptionComplete: subscriptionComplete,
      hasSubscription: hasSubscription,
      subscriptionStatus: subscriptionStatus,
      profileVerificationStatus: profileData?['verification_status']
          ?.toString(),
      isProfileVerified: profileData?['is_verified'] as bool?,
    );
  }

  Future<Map<String, dynamic>?> _safeGetMap(
    String path, {
    required String label,
  }) async {
    try {
      final response = await _apiService.get(path);
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        AppLogger.w('[Onboarding] Unexpected $label payload for $path');
        return null;
      }
      return _unwrapData(body);
    } on DioException catch (e) {
      AppLogger.w(
        '[Onboarding] $label request failed: ${e.response?.statusCode ?? e.type.name}',
      );
      return null;
    } catch (e, st) {
      AppLogger.e('[Onboarding] $label request failed', e, st);
      return null;
    }
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic> body) {
    final nested = body['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return body;
  }

  int _countUploadedRequiredDocuments(Map<String, dynamic> documentsData) {
    final rawDocuments =
        documentsData['documents'] ?? documentsData['results'] ?? documentsData;

    if (rawDocuments is! List) {
      return 0;
    }

    final uploadedTypes = <String>{};

    for (final item in rawDocuments) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final type =
          item['document_type']?.toString() ?? item['type']?.toString();
      if (type != null && _requiredDocumentTypes.contains(type)) {
        uploadedTypes.add(type);
      }
    }

    return uploadedTypes.length;
  }
}
