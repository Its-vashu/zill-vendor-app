// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ── Endpoints ────────────────────────────────────────────────────────
// Mirrors `food-delivery-api/vendors/urls.py` lines 111-117. The
// canonical contract for each endpoint is documented in the launch-day
// audit report — Flutter speaks exactly that.
extension _BulkEndpoints on ApiEndpoints {
  static const String bulkUploadCsv = '/vendors/menu-items/bulk-upload-csv/';
  static const String bulkUploadTemplate =
      '/vendors/menu-items/bulk-upload-template/';
  static const String bulkUploadImages =
      '/vendors/menu-items/bulk-upload-images/';
  static const String bulkUploadMenuPhoto =
      '/vendors/menu-items/bulk-upload-menu-photo/';
  static const String autoFetchImages =
      '/vendors/menu-items/auto-fetch-images/';
}

// ── ViewModel ────────────────────────────────────────────────────────
class BulkUploadViewModel extends ChangeNotifier {
  BulkUploadViewModel({required ApiService apiService})
    : _api = apiService;

  final ApiService _api;
  bool _isDisposed = false;

  // ── CSV state ──────────────────────────────────────────────────────
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  PlatformFile? _selectedFile;
  String? _errorMessage;
  Map<String, dynamic>? _uploadResult;

  // ── CSV toggles ────────────────────────────────────────────────────
  bool _clearExisting = false;
  bool _updateExisting = false;
  bool _autoFetchImages = false;

  // ── Bulk Images state ──────────────────────────────────────────────
  // Up to N images picked from gallery; backend auto-matches each
  // file's name to an existing menu item ("butter_chicken.jpg" →
  // "Butter Chicken"). 50 MB total cap (matches backend).
  static const int _maxBulkImagesBytes = 50 * 1024 * 1024;
  final List<XFile> _selectedImages = [];
  bool _isImagesUploading = false;
  double _imagesProgress = 0.0;
  Map<String, dynamic>? _imagesResult;

  // ── Menu Photo OCR state ───────────────────────────────────────────
  // Single photo of a printed menu card; backend OCR extracts items.
  // 10 MB cap. Two-step flow: preview → confirm save.
  static const int _maxMenuPhotoBytes = 10 * 1024 * 1024;
  XFile? _menuPhoto;
  bool _isOcrLoading = false;
  Map<String, dynamic>? _ocrPreview;
  Map<String, dynamic>? _ocrResult;

  // ── Auto-fetch state ───────────────────────────────────────────────
  bool _isAutoFetching = false;
  Map<String, dynamic>? _autoFetchResult;

  // ── CSV getters ────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  double get uploadProgress => _uploadProgress;
  PlatformFile? get selectedFile => _selectedFile;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get uploadResult => _uploadResult;

  bool get clearExisting => _clearExisting;
  bool get updateExisting => _updateExisting;
  bool get autoFetchImages => _autoFetchImages;

  bool get canUpload => !_isLoading && _selectedFile != null;

  // ── Bulk Images getters ────────────────────────────────────────────
  List<XFile> get selectedImages => List.unmodifiable(_selectedImages);
  bool get isImagesUploading => _isImagesUploading;
  double get imagesProgress => _imagesProgress;
  Map<String, dynamic>? get imagesResult => _imagesResult;
  bool get canUploadImages =>
      !_isImagesUploading && _selectedImages.isNotEmpty;
  int get selectedImagesTotalBytes {
    int total = 0;
    for (final img in _selectedImages) {
      try {
        total += File(img.path).lengthSync();
      } catch (_) {}
    }
    return total;
  }

  // ── Menu Photo getters ─────────────────────────────────────────────
  XFile? get menuPhoto => _menuPhoto;
  bool get isOcrLoading => _isOcrLoading;
  Map<String, dynamic>? get ocrPreview => _ocrPreview;
  Map<String, dynamic>? get ocrResult => _ocrResult;
  bool get canRunOcr => !_isOcrLoading && _menuPhoto != null;

  // ── Auto-fetch getters ─────────────────────────────────────────────
  bool get isAutoFetching => _isAutoFetching;
  Map<String, dynamic>? get autoFetchResult => _autoFetchResult;

  // ── Notify guard ──────────────────────────────────────────────────
  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── Toggle setters ────────────────────────────────────────────────
  void toggleClearExisting(bool v) {
    _clearExisting = v;
    _notify();
  }

  void toggleUpdateExisting(bool v) {
    _updateExisting = v;
    _notify();
  }

  void toggleAutoFetchImages(bool v) {
    _autoFetchImages = v;
    _notify();
  }

  // ── Clear file selection ──────────────────────────────────────────
  void clearFile() {
    _selectedFile = null;
    _uploadResult = null;
    _errorMessage = null;
    _uploadProgress = 0.0;
    _notify();
  }

  // ── Pick CSV file ─────────────────────────────────────────────────
  /// Max allowed file size: 5 MB.
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: false, // stream from disk for large files
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.path == null) {
        _errorMessage = 'Could not access the selected file.';
        _notify();
        return;
      }

      // ── 5 MB size guard ──────────────────────────────────────────
      final size = file.size;
      if (size > _maxFileSizeBytes) {
        final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
        _errorMessage =
            'File is too large ($sizeMb MB). Maximum allowed size is 5 MB.';
        _selectedFile = null;
        _notify();
        return;
      }

      _selectedFile = file;
      _uploadResult = null;
      _errorMessage = null;
      _notify();
    } catch (e) {
      _errorMessage = 'File picker error: $e';
      _notify();
    }
  }

  /// Last successful template save path. Surfaced to the screen so it
  /// can show "Saved to {path}" feedback and an "Open" action.
  String? _lastTemplatePath;
  String? get lastTemplatePath => _lastTemplatePath;

  // ── Download template ─────────────────────────────────────────────
  // Saves the CSV into the app's documents directory (persistent,
  // accessible via Files app on iOS / Android Files), then opens the
  // share sheet so the user can save it to Drive, email it, etc.
  // Path is stored in `_lastTemplatePath` so the UI can also show a
  // "Saved to ..." snackbar.
  Future<void> downloadTemplate() async {
    _isLoading = true;
    _errorMessage = null;
    _lastTemplatePath = null;
    _notify();

    try {
      final response = await _api.dio.get<List<int>>(
        _BulkEndpoints.bulkUploadTemplate,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty response from server.');
      }

      // Persistent location — survives across app restarts (unlike
      // getTemporaryDirectory which the OS may purge).
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/zill_menu_upload_template.csv');
      await file.writeAsBytes(bytes);
      _lastTemplatePath = file.path;

      // Offer the OS share sheet so the user can stash it in Drive,
      // email, WhatsApp, etc.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Zill Menu Upload Template',
          text: 'Fill in your menu items and upload via the Zill '
              'Restaurant Partner app.',
        ),
      );
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Failed to download template: $e';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // ── Upload CSV ────────────────────────────────────────────────────
  Future<void> uploadMenu() async {
    if (_selectedFile?.path == null) return;

    _isLoading = true;
    _uploadProgress = 0.0;
    _uploadResult = null;
    _errorMessage = null;
    _notify();

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path!,
          filename: _selectedFile!.name,
        ),
        'clear_existing': _clearExisting.toString(),
        'update_existing': _updateExisting.toString(),
        'auto_fetch_images': _autoFetchImages.toString(),
      });

      final response = await _api.dio.post(
        _BulkEndpoints.bulkUploadCsv,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          // Backend returns HTTP 201 on partial success, 400 on hard
          // failure. We accept 200/201 ourselves and convert any 4xx
          // payload (which carries `error`) into _errorMessage below.
          validateStatus: (s) => s != null && s < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && !_isDisposed) {
            _uploadProgress = sent / total;
            _notify();
          }
        },
      );

      final body = response.data as Map<String, dynamic>?;
      final code = response.statusCode ?? 0;

      // Treat any 2xx as success — backend uses 201 for both clean
      // imports and partial-success responses, and the response body
      // (even when summary.errors is non-empty) carries the real
      // counts the result card needs to render.
      if (code >= 200 && code < 300 && body != null) {
        _uploadResult = body;
        _selectedFile = null; // reset after success
      } else {
        // 4xx — backend rejected the file outright (bad columns,
        // wrong type, etc). Surface its `error` string as a snackbar.
        _errorMessage = body?['error']?.toString() ??
            body?['detail']?.toString() ??
            'Upload failed (HTTP $code).';
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isLoading = false;
      _uploadProgress = 0.0;
      _notify();
    }
  }

  // ── Error helpers ─────────────────────────────────────────────────
  String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['detail']?.toString() ??
          'Server error (${e.response?.statusCode}).';
    }
    return 'Server error (${e.response?.statusCode ?? 'unknown'}).';
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK IMAGES UPLOAD
  //  POST /vendors/menu-items/bulk-upload-images/
  //  FormData: { images: File[] }  (auto-match by filename)
  //  Backend cap: 50 MB total, jpg/jpeg/png/gif/webp
  // ═══════════════════════════════════════════════════════════════════

  /// Pick multiple images from gallery. Appends to the existing
  /// selection so the user can pick in batches.
  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;

      // Combine new picks with existing, dedupe by path
      final byPath = {for (final f in _selectedImages) f.path: f};
      for (final f in picked) {
        byPath[f.path] = f;
      }
      _selectedImages
        ..clear()
        ..addAll(byPath.values);

      // Enforce 50 MB total
      if (selectedImagesTotalBytes > _maxBulkImagesBytes) {
        final mb =
            (selectedImagesTotalBytes / (1024 * 1024)).toStringAsFixed(1);
        _errorMessage =
            'Total selected images ($mb MB) exceed the 50 MB limit. '
            'Please remove some images.';
      } else {
        _errorMessage = null;
      }
      _imagesResult = null;
      _notify();
    } catch (e) {
      _errorMessage = 'Could not open image picker: $e';
      _notify();
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    _selectedImages.removeAt(index);
    _imagesResult = null;
    _notify();
  }

  void clearImages() {
    _selectedImages.clear();
    _imagesResult = null;
    _imagesProgress = 0.0;
    _errorMessage = null;
    _notify();
  }

  Future<void> uploadImages() async {
    if (_selectedImages.isEmpty) return;

    if (selectedImagesTotalBytes > _maxBulkImagesBytes) {
      _errorMessage =
          'Total size exceeds 50 MB. Please remove some images first.';
      _notify();
      return;
    }

    _isImagesUploading = true;
    _imagesProgress = 0.0;
    _imagesResult = null;
    _errorMessage = null;
    _notify();

    try {
      // Backend expects multiple files under the same form field name
      // "images". MultipartFile.fromFile each picked XFile and pass
      // them as a list under that key.
      final multiparts = <MapEntry<String, MultipartFile>>[];
      for (final img in _selectedImages) {
        multiparts.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(img.path, filename: img.name),
          ),
        );
      }
      final formData = FormData()..files.addAll(multiparts);

      final response = await _api.dio.post(
        _BulkEndpoints.bulkUploadImages,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (s) => s != null && s < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && !_isDisposed) {
            _imagesProgress = sent / total;
            _notify();
          }
        },
      );

      final body = response.data as Map<String, dynamic>?;
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300 && body != null) {
        _imagesResult = body;
        _selectedImages.clear();
      } else {
        _errorMessage = body?['error']?.toString() ??
            body?['detail']?.toString() ??
            'Image upload failed (HTTP $code).';
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isImagesUploading = false;
      _imagesProgress = 0.0;
      _notify();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MENU PHOTO OCR
  //  POST /vendors/menu-items/bulk-upload-menu-photo/
  //  FormData: { image, preview_only, clear_existing, update_existing,
  //              auto_fetch_images }
  //  Two-step: preview_only=true → review extracted_data → re-upload
  //  with preview_only=false to commit.
  // ═══════════════════════════════════════════════════════════════════

  Future<void> pickMenuPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (photo == null) return;

      final size = await File(photo.path).length();
      if (size > _maxMenuPhotoBytes) {
        final mb = (size / (1024 * 1024)).toStringAsFixed(1);
        _errorMessage =
            'Photo is too large ($mb MB). Maximum allowed size is 10 MB.';
        _notify();
        return;
      }

      _menuPhoto = photo;
      _ocrPreview = null;
      _ocrResult = null;
      _errorMessage = null;
      _notify();
    } catch (e) {
      _errorMessage = 'Could not pick menu photo: $e';
      _notify();
    }
  }

  void clearMenuPhoto() {
    _menuPhoto = null;
    _ocrPreview = null;
    _ocrResult = null;
    _errorMessage = null;
    _notify();
  }

  /// Step 1: send the photo with preview_only=true so the backend
  /// runs OCR and returns the extracted categories/items WITHOUT
  /// touching the database. The user reviews `ocrPreview` next.
  Future<void> previewMenuPhoto() async {
    if (_menuPhoto == null) return;

    _isOcrLoading = true;
    _ocrPreview = null;
    _ocrResult = null;
    _errorMessage = null;
    _notify();

    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          _menuPhoto!.path,
          filename: _menuPhoto!.name,
        ),
        'preview_only': 'true',
      });

      final response = await _api.dio.post(
        _BulkEndpoints.bulkUploadMenuPhoto,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          // OCR is slow on the backend (Tesseract). Bump receive
          // timeout so 15-30s OCR runs don't time out.
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 60),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final body = response.data as Map<String, dynamic>?;
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300 && body != null) {
        _ocrPreview = body;
      } else {
        // Backend returns 422 with `error` and `hint` if OCR couldn't
        // extract anything — surface both for the user.
        final err = body?['error']?.toString();
        final hint = body?['hint']?.toString();
        final parts = [?err, ?hint];
        _errorMessage = parts.isEmpty
            ? 'OCR failed (HTTP $code).'
            : parts.join(' • ');
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isOcrLoading = false;
      _notify();
    }
  }

  /// Step 2: commit by re-uploading the same photo with
  /// preview_only=false. Backend re-OCRs and saves to DB.
  Future<void> saveMenuPhoto() async {
    if (_menuPhoto == null) return;

    _isOcrLoading = true;
    _ocrResult = null;
    _errorMessage = null;
    _notify();

    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          _menuPhoto!.path,
          filename: _menuPhoto!.name,
        ),
        'preview_only': 'false',
        // Reuse the CSV toggles so user keeps consistent control
        // over destructive ops.
        'clear_existing': _clearExisting.toString(),
        'update_existing': _updateExisting.toString(),
        'auto_fetch_images': _autoFetchImages.toString(),
      });

      final response = await _api.dio.post(
        _BulkEndpoints.bulkUploadMenuPhoto,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final body = response.data as Map<String, dynamic>?;
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300 && body != null) {
        _ocrResult = body;
        // Clear preview + photo so the screen returns to a fresh state
        _ocrPreview = null;
        _menuPhoto = null;
      } else {
        _errorMessage = body?['error']?.toString() ??
            'Save failed (HTTP $code).';
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isOcrLoading = false;
      _notify();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  AUTO-FETCH IMAGES (Unsplash)
  //  POST /vendors/menu-items/auto-fetch-images/
  //  JSON body: { item_ids?: int[], category_id?: int, overwrite?: bool }
  //  Empty body = fetch for ALL items without existing images.
  // ═══════════════════════════════════════════════════════════════════

  Future<void> triggerAutoFetchImages({
    List<int>? itemIds,
    int? categoryId,
    bool overwrite = false,
  }) async {
    _isAutoFetching = true;
    _autoFetchResult = null;
    _errorMessage = null;
    _notify();

    try {
      final body = <String, dynamic>{};
      if (itemIds != null && itemIds.isNotEmpty) body['item_ids'] = itemIds;
      if (categoryId != null) body['category_id'] = categoryId;
      if (overwrite) body['overwrite'] = true;

      final response = await _api.dio.post(
        _BulkEndpoints.autoFetchImages,
        data: body,
        options: Options(
          contentType: 'application/json',
          // Unsplash bulk fetch is slow because backend rate-limits at
          // 0.3s per image — 50 items ≈ 15s. Bump receive timeout.
          receiveTimeout: const Duration(seconds: 90),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final data = response.data as Map<String, dynamic>?;
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300 && data != null) {
        _autoFetchResult = data;
      } else {
        _errorMessage = data?['error']?.toString() ??
            'Auto-fetch failed (HTTP $code).';
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isAutoFetching = false;
      _notify();
    }
  }

  void clearAutoFetchResult() {
    _autoFetchResult = null;
    _notify();
  }
}
