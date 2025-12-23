// profile_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Create or update user profile after successful OTP verification
  static Future<Map<String, dynamic>?> createOrUpdateProfile({
    required String phone,
    required String fullName,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if profile already exists
      final existingProfile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      Map<String, dynamic> profileData = {
        'phone': phone,
        'full_name': fullName,
      };

      if (existingProfile == null) {
        // Create new profile
        profileData['id'] = user.id;
        final response = await _client
            .from('profiles')
            .insert(profileData)
            .select()
            .single();

        print('Profile created successfully');
        return response;
      } else {
        // Update existing profile
        final response = await _client
            .from('profiles')
            .update(profileData)
            .eq('id', user.id)
            .select()
            .single();

        print('Profile updated successfully');
        return response;
      }
    } catch (e) {
      print('Error creating/updating profile: $e');
      rethrow;
    }
  }

  /// Get current user's profile
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return null;
      }

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return profile;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  /// Update profile avatar URL
  static Future<Map<String, dynamic>?> updateAvatarUrl(String avatarUrl) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id)
          .select()
          .single();

      print('Avatar URL updated successfully');
      return response;
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
    }
  }

  /// Delete current user's profile
  static Future<void> deleteProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('profiles')
          .delete()
          .eq('id', user.id);

      print('Profile deleted successfully');
    } catch (e) {
      print('Error deleting profile: $e');
      rethrow;
    }
  }
}