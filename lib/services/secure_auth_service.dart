import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';
import '../utils/security_logger.dart';
import 'secure_storage_service.dart';

class SecureAuthService with ChangeNotifier {
  final SecureStorageService _storageService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
  
  UserProfile? _currentUser;
  bool _isLoading = false;
  
  // Session management
  static const String _sessionKey = 'current_user_email';
  static const String _sessionValidKey = 'session_valid';
  
  // Authentication settings
  static const int _maxLoginAttempts = 5;
  static const int _lockoutDurationMinutes = 15;
  static const int _minPasswordLength = 4;
  
  // Store login attempts
  final Map<String, List<DateTime>> _loginAttempts = {};
  
  // Constructor
  SecureAuthService(this._storageService);
  
  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  
  // Initialize the service
  Future<void> initialize() async {
    SecurityLogger.info('=== INITIALIZING AUTH SERVICE ===');
    _isLoading = true;
    notifyListeners();
    
    try {
      await _storageService.initialize();
      await _restoreSession();
      await _debugStorageContents();
    } catch (e) {
      SecurityLogger.error('Error initializing auth service: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Debug helper to see what's in storage
  Future<void> _debugStorageContents() async {
    try {
      SecurityLogger.info('=== STORAGE DEBUG ===');
      final keys = [
        'current_user_email',
        'session_valid',
        'test_key_12345',
      ];
      
      for (String key in keys) {
        final value = await _secureStorage.read(key: key);
        SecurityLogger.info('Key: $key -> Value exists: ${value != null}');
      }
    } catch (e) {
      SecurityLogger.error('Debug storage error: ${e.toString()}');
    }
  }
  
  // Test storage functionality
  Future<bool> _testSecureStorage() async {
    try {
      const testKey = 'test_key_12345';
      const testValue = 'test_value_12345';
      
      await _secureStorage.write(key: testKey, value: testValue);
      final readValue = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      
      final success = readValue == testValue;
      SecurityLogger.info('Storage test result: $success');
      return success;
    } catch (e) {
      SecurityLogger.error('Storage test failed: ${e.toString()}');
      return false;
    }
  }
  
  // Restore session from storage
  Future<void> _restoreSession() async {
    try {
      SecurityLogger.info('=== RESTORING SESSION ===');
      
      final storageWorking = await _testSecureStorage();
      if (!storageWorking) {
        SecurityLogger.error('Storage not working, cannot restore session');
        return;
      }
      
      final currentUserEmail = await _secureStorage.read(key: _sessionKey);
      final sessionValid = await _secureStorage.read(key: _sessionValidKey);
      
      SecurityLogger.info('Stored email: $currentUserEmail');
      SecurityLogger.info('Session valid: $sessionValid');
      
      if (currentUserEmail != null && sessionValid == 'true') {
        final userData = await _secureStorage.read(key: 'userdata_$currentUserEmail');
        if (userData != null) {
          _currentUser = UserProfile.fromJson(jsonDecode(userData));
          SecurityLogger.info('Session restored successfully: $currentUserEmail');
        } else {
          SecurityLogger.warn('User data not found, clearing session');
          await _clearSession();
        }
      } else {
        SecurityLogger.info('No valid session found');
      }
    } catch (e) {
      SecurityLogger.error('Error restoring session: ${e.toString()}');
      await _clearSession();
    }
  }
  
  // Save session
  Future<void> _saveSession(String email) async {
    try {
      await _secureStorage.write(key: _sessionKey, value: email);
      await _secureStorage.write(key: _sessionValidKey, value: 'true');
      SecurityLogger.info('Session saved for: $email');
    } catch (e) {
      SecurityLogger.error('Error saving session: ${e.toString()}');
    }
  }
  
  // Clear session
  Future<void> _clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
      await _secureStorage.delete(key: _sessionValidKey);
      SecurityLogger.info('Session cleared');
    } catch (e) {
      SecurityLogger.error('Error clearing session: ${e.toString()}');
    }
  }
  
  // Hash password
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Generate salt
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  // Validate email
  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }
  
  // Check lockout
  bool _isUserLocked(String email) {
    if (!_loginAttempts.containsKey(email)) return false;
    
    final now = DateTime.now();
    final recentAttempts = _loginAttempts[email]!.where(
      (attempt) => now.difference(attempt).inMinutes < _lockoutDurationMinutes
    ).toList();
    
    _loginAttempts[email] = recentAttempts;
    return recentAttempts.length >= _maxLoginAttempts;
  }
  
  // Record attempt
  void _recordLoginAttempt(String email) {
    _loginAttempts[email] ??= [];
    _loginAttempts[email]!.add(DateTime.now());
  }
  
  // Reset attempts
  void _resetLoginAttempts(String email) {
    _loginAttempts.remove(email);
  }
  
  // SIGN UP - Version simplifiée pour éviter les erreurs
  Future<Map<String, dynamic>> signUp(String username, String email, String password) async {
    SecurityLogger.info('=== SIGN UP START ===');
    
    if (!_isValidEmail(email)) {
      return {'success': false, 'message': 'Email invalide'};
    }
    
    if (password.length < _minPasswordLength) {
      return {'success': false, 'message': 'Mot de passe trop court'};
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Test storage
      if (!await _testSecureStorage()) {
        return {'success': false, 'message': 'Erreur de stockage'};
      }
      
      // Create credentials
      final salt = _generateSalt();
      final hashedPassword = _hashPassword(password, salt);
      final userProfile = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: username,
        email: email,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      
      // Save credentials
      await _secureStorage.write(key: 'password_$email', value: hashedPassword);
      await _secureStorage.write(key: 'salt_$email', value: salt);
      await _secureStorage.write(key: 'userdata_$email', value: jsonEncode(userProfile.toJson()));
      
      // Verify save
      final savedPassword = await _secureStorage.read(key: 'password_$email');
      final savedSalt = await _secureStorage.read(key: 'salt_$email');
      final savedUserData = await _secureStorage.read(key: 'userdata_$email');
      
      SecurityLogger.info('Save verification:');
      SecurityLogger.info('- Password saved: ${savedPassword != null}');
      SecurityLogger.info('- Salt saved: ${savedSalt != null}');
      SecurityLogger.info('- User data saved: ${savedUserData != null}');
      
      if (savedPassword == null || savedSalt == null || savedUserData == null) {
        SecurityLogger.error('SAVE FAILED - Data not persisted');
        return {'success': false, 'message': 'Erreur lors de la sauvegarde'};
      }
      
      // Auto-login
      _currentUser = userProfile;
      await _saveSession(email);
      
      SecurityLogger.info('=== SIGN UP SUCCESS ===');
      return {'success': true, 'message': 'Inscription réussie'};
      
    } catch (e) {
      SecurityLogger.error('Sign up error: ${e.toString()}');
      return {'success': false, 'message': 'Erreur: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // SIGN IN - Version simplifiée
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    SecurityLogger.info('=== SIGN IN START ===');
    
    if (!_isValidEmail(email)) {
      return {'success': false, 'message': 'Email invalide'};
    }
    
    if (_isUserLocked(email)) {
      return {'success': false, 'message': 'Compte verrouillé'};
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Test storage
      if (!await _testSecureStorage()) {
        return {'success': false, 'message': 'Erreur de stockage'};
      }
      
      // Get stored data
      final storedPassword = await _secureStorage.read(key: 'password_$email');
      final storedSalt = await _secureStorage.read(key: 'salt_$email');
      final userData = await _secureStorage.read(key: 'userdata_$email');
      
      SecurityLogger.info('Data retrieval:');
      SecurityLogger.info('- Password found: ${storedPassword != null}');
      SecurityLogger.info('- Salt found: ${storedSalt != null}');
      SecurityLogger.info('- User data found: ${userData != null}');
      
      if (storedPassword == null || storedSalt == null || userData == null) {
        SecurityLogger.error('USER NOT FOUND - Missing data');
        _recordLoginAttempt(email);
        return {'success': false, 'message': 'Utilisateur non trouvé'};
      }
      
      // Verify password
      final hashedInputPassword = _hashPassword(password, storedSalt);
      if (hashedInputPassword != storedPassword) {
        SecurityLogger.info('Password mismatch');
        _recordLoginAttempt(email);
        return {'success': false, 'message': 'Mot de passe incorrect'};
      }
      
      // Login successful
      _currentUser = UserProfile.fromJson(jsonDecode(userData));
      await _saveSession(email);
      _resetLoginAttempts(email);
      
      SecurityLogger.info('=== SIGN IN SUCCESS ===');
      return {'success': true, 'message': 'Connexion réussie'};
      
    } catch (e) {
      SecurityLogger.error('Sign in error: ${e.toString()}');
      return {'success': false, 'message': 'Erreur: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // SIGN OUT - Version sécurisée
  Future<void> signOut() async {
    SecurityLogger.info('=== SIGN OUT START ===');
    
    try {
      // Clear session first
      await _clearSession();
      
      // Clear current user
      _currentUser = null;
      
      SecurityLogger.info('=== SIGN OUT SUCCESS ===');
    } catch (e) {
      SecurityLogger.error('Sign out error: ${e.toString()}');
    } finally {
      // Always notify, even if there's an error
      try {
        notifyListeners();
      } catch (e) {
        SecurityLogger.error('Error notifying listeners: ${e.toString()}');
      }
    }
  }
  
  // Update profile
  Future<bool> updateProfile({String? username, String? bio, String? avatarUrl}) async {
    if (_currentUser == null) return false;
    
    try {
      _currentUser = _currentUser!.copyWith(
        username: username ?? _currentUser!.username,
        bio: bio ?? _currentUser!.bio,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      );
      
      await _secureStorage.write(
        key: 'userdata_${_currentUser!.email}', 
        value: jsonEncode(_currentUser!.toJson())
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      SecurityLogger.error('Update profile error: ${e.toString()}');
      return false;
    }
  }
  
  // Password strength check
  Map<String, dynamic> checkPasswordStrength(String password) {
    bool isValid = password.length >= _minPasswordLength;
    List<String> weaknesses = [];
    
    if (!isValid) {
      weaknesses.add('Minimum $_minPasswordLength caractères requis');
    }
    
    return {
      'isValid': isValid,
      'strength': isValid ? 75 : 25,
      'weaknesses': weaknesses,
    };
  }
  
  // Clear all data
  Future<void> clearAllUserData() async {
    try {
      SecurityLogger.info('=== CLEARING ALL DATA ===');
      await _secureStorage.deleteAll();
      _currentUser = null;
      SecurityLogger.info('All data cleared');
      notifyListeners();
    } catch (e) {
      SecurityLogger.error('Error clearing data: ${e.toString()}');
    }
  }
}