import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;
  static const String bucket = 'reports';

  Future<String?> uploadFile(File file, String userId) =>
      _upload(file, userId);

  Future<String?> _upload(File file, String userId) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    try {
      await client.storage.from(bucket).upload(path, file);
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      rethrow;
    }
  }

}
