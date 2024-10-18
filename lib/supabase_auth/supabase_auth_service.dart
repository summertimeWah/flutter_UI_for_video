import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_for_yolov7/toast_set/toast.dart';

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 註冊新用戶
  Future<AuthResponse?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // 成功註冊
        showToast(message: 'User registered successfully.');
      } else {
        // 如果註冊失敗，顯示錯誤消息
        showToast(message: 'Error occurred during registration.');
      }
      return response;
    } catch (e) {
      if (e is AuthException) {
        showToast(message: 'Error: ${e.message}');
      } else {
        showToast(message: 'An error occurred: $e');
      }
    }
    return null;
  }

  // 用電子郵件和密碼登入
  Future<AuthResponse?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        // 成功登入
        showToast(message: 'User signed in successfully.');
      } else {
        // 如果登入失敗，顯示錯誤消息
        showToast(message: 'Invalid email or password.');
      }
      return response;
    } catch (e) {
      if (e is AuthException) {
        showToast(message: 'Error: ${e.message}');
      } else {
        showToast(message: 'An error occurred: $e');
      }
    }
    return null;
  }
}
