import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Quản lý lưu trữ file cục bộ: Map ngoại tuyến, cache model, logs.
/// KHÔNG BAO GIỜ ghi vào assets/ (đó là read-only bundled).
/// Luôn ghi vào getApplicationDocumentsDirectory() hoặc getTemporaryDirectory().
class FileStorageService {
  Directory? _docsDir;
  Directory? _cacheDir;

  Future<void> init() async {
    _docsDir = await getApplicationDocumentsDirectory();
    _cacheDir = await getTemporaryDirectory();
  }

  /// Thư mục lưu bản đồ ngoại tuyến (tải từ Cloudflare R2)
  Future<Directory> getOfflineMapsDir() async {
    final dir = Directory('${(await _getDocsDir()).path}/offline_maps');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Thư mục lưu model đã giải nén (copy từ assets ra filesystem)
  Future<Directory> getModelsDir() async {
    final dir = Directory('${(await _getDocsDir()).path}/models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lưu file từ bytes (VD: tải map zip từ R2)
  Future<File> saveFile(String subPath, List<int> bytes) async {
    final file = File('${(await _getDocsDir()).path}/$subPath');
    await file.parent.create(recursive: true);
    return await file.writeAsBytes(bytes);
  }

  /// Đọc file
  Future<List<int>?> readFile(String subPath) async {
    final file = File('${(await _getDocsDir()).path}/$subPath');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  /// Kiểm tra file tồn tại
  Future<bool> fileExists(String subPath) async {
    final file = File('${(await _getDocsDir()).path}/$subPath');
    return await file.exists();
  }

  Future<Directory> _getDocsDir() async {
    _docsDir ??= await getApplicationDocumentsDirectory();
    return _docsDir!;
  }

  /// Thư mục cache tạm (có thể bị OS xóa khi cần)
  Future<Directory> getCacheDir() async {
    _cacheDir ??= await getTemporaryDirectory();
    return _cacheDir!;
  }
}
