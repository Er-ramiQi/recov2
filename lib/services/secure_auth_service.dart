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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  UserProfile? _currentUser;
  bool _isLoading = false;
  
  // Authentication settings
  static const int _maxLoginAttempts = 5;
  static const int _lockoutDurationMinutes = 15;
  static const int _minPasswordLength = 8;
  static const bool _requireUppercase = true;
  static const bool _requireLowercase = true;
  static const bool _requireNumbers = true;
  static const bool _requireSpecialChars = true;
  
  // Store login attempts to prevent brute force attacks
  final Map<String, List<DateTime>> _loginAttempts = {};
  
  // Constructor
  SecureAuthService(this._storageService);
  
  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  
  // Initialize the service
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _storageService.initialize();
      final userData = await _storageService.getUserProfile();
      if (userData != null) {
        _currentUser = userData;
      }
    } catch (e) {
      SecurityLogger.error('Error initializing auth service: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Hash a password with salt
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Generate a random salt
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,});
    return emailRegex.hasMatch(email);
  }
  
  // Check if a user is locked out due to too many attempts
  bool _isUserLocked(String email) {
    if (!_loginAttempts.containsKey(email) || _loginAttempts[email]!.isEmpty) {
      return false;
    }
    
    // Filter attempts to only include those within the lockout window
    final now = DateTime.now();
    final lockoutThreshold = now.subtract(Duration(minutes: _lockoutDurationMinutes));
    final recentAttempts = _loginAttempts[email]!.where(
      (attempt) => attempt.isAfter(lockoutThreshold)
    ).toList();
    
    _loginAttempts[email] = recentAttempts;
    
    // Check if there are too many recent attempts
    return recentAttempts.length >= _maxLoginAttempts;
  }
  
  // Get remaining time in lockout
  int _getRemainingLockTime(String email) {
    if (!_loginAttempts.containsKey(email) || _loginAttempts[email]!.isEmpty) {
      return 0;
    }
    
    final now = DateTime.now();
    final oldestAttempt = _loginAttempts[email]!.reduce(
      (a, b) => a.isBefore(b) ? a : b
    );
    
    final lockoutEnd = oldestAttempt.add(Duration(minutes: _lockoutDurationMinutes));
    final remainingSeconds = lockoutEnd.difference(now).inSeconds;
    
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }
  
  // Record a login attempt
  void _recordLoginAttempt(String email) {
    if (!_loginAttempts.containsKey(email)) {
      _loginAttempts[email] = [];
    }
    
    _loginAttempts[email]!.add(DateTime.now());
  }
  
  // Reset login attempts
  void _resetLoginAttempts(String email) {
    _loginAttempts.remove(email);
  }
  
  // Sign in with email and password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      return {
        'success': false,
        'message': 'Format d\'email invalide',
      };
    }
    
    // Check if the user is locked out
    if (_isUserLocked(email)) {
      return {
        'success': false,
        'message': 'Compte temporairement verrouillé suite à trop de tentatives.',
        'isLocked': true,
        'remainingTime': _getRemainingLockTime(email),
      };
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Add a random delay to prevent timing attacks
      await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));
      
      // Get stored credentials
      final storedHashedPassword = await _secureStorage.read(key: 'password_$email');
      final storedSalt = await _secureStorage.read(key: 'salt_$email');
      
      // Check if user exists
      if (storedHashedPassword == null || storedSalt == null) {
        _recordLoginAttempt(email);
        return {
          'success': false,
          'message': 'Email ou mot de passe incorrect',
          'attemptsLeft': _maxLoginAttempts - (_loginAttempts[email]?.length ?? 0),
        };
      }
      
      // Hash the provided password with the stored salt
      final hashedPassword = _hashPassword(password, storedSalt);
      
      // Check if passwords match
      if (hashedPassword != storedHashedPassword) {
        _recordLoginAttempt(email);
        return {
          'success': false,
          'message': 'Email ou mot de passe incorrect',
          'attemptsLeft': _maxLoginAttempts - (_loginAttempts[email]?.length ?? 0),
        };
      }
      
      // Load user profile
      final userData = await _secureStorage.read(key: 'userdata_$email');
      if (userData != null) {
        _currentUser = UserProfile.fromJson(jsonDecode(userData));
        await _storageService.saveUserProfile(_currentUser!);
      } else {
        // Create a new profile if none exists
        _currentUser = UserProfile(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: email.split('@')[0],
          email: email,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        
        // Save the profile
        await _secureStorage.write(
          key: 'userdata_$email', 
          value: jsonEncode(_currentUser!.toJson())
        );
        await _storageService.saveUserProfile(_currentUser!);
      }
      
      // Update last login time
      _currentUser = _currentUser!.copyWith(lastLogin: DateTime.now());
      await _secureStorage.write(
        key: 'userdata_$email', 
        value: jsonEncode(_currentUser!.toJson())
      );
      await _storageService.saveUserProfile(_currentUser!);
      
      // Reset login attempts on successful login
      _resetLoginAttempts(email);
      
      SecurityLogger.info('User logged in: $email');
      
      return {
        'success': true,
        'message': 'Connexion réussie',
      };
    } catch (e) {
      SecurityLogger.error('Sign in error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Une erreur est survenue lors de la connexion',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign up with email and password
  Future<Map<String, dynamic>> signUp(String username, String email, String password) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      return {
        'success': false,
        'message': 'Format d\'email invalide',
      };
    }
    
    // Check password strength
    final passwordCheck = checkPasswordStrength(password);
    if (!passwordCheck['isValid']) {
      return {
        'success': false,
        'message': 'Mot de passe trop faible',
        'details': passwordCheck['weaknesses'],
      };
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check if email already exists
      final existingPassword = await _secureStorage.read(key: 'password_$email');
      if (existingPassword != null) {
        return {
          'success': false,
          'message': 'Cet email est déjà utilisé',
        };
      }
      
      // Generate salt and hash password
      final salt = _generateSalt();
      final hashedPassword = _hashPassword(password, salt);
      
      // Create user profile
      _currentUser = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: username,
        email: email,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      
      // Store credentials securely
      await _secureStorage.write(key: 'password_$email', value: hashedPassword);
      await _secureStorage.write(key: 'salt_$email', value: salt);
      await _secureStorage.write(
        key: 'userdata_$email', 
        value: jsonEncode(_currentUser!.toJson())
      );
      
      // Save to profile storage
      await _storageService.saveUserProfile(_currentUser!);
      
      SecurityLogger.info('New user registered: $email');
      
      return {
        'success': true,
        'message': 'Inscription réussie',
      };
    } catch (e) {
      SecurityLogger.error('Sign up error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Une erreur est survenue lors de l\'inscription',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      SecurityLogger.info('User logged out: ${_currentUser?.email}');
      _currentUser = null;
      await _storageService.clearUserProfile();
    } catch (e) {
      SecurityLogger.error('Sign out error: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update profile
  Future<bool> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
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
      await _storageService.saveUserProfile(_currentUser!);
      
      return true;
    } catch (e) {
      SecurityLogger.error('Update profile error: ${e.toString()}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Check password strength
  Map<String, dynamic> checkPasswordStrength(String password) {
    bool hasUppercase = _requireUppercase ? password.contains(RegExp(r'[A-Z]')) : true;
    bool hasLowercase = _requireLowercase ? password.contains(RegExp(r'[a-z]')) : true;
    bool hasNumber = _requireNumbers ? password.contains(RegExp(r'[0-9]')) : true;
    bool hasSpecialChar = _requireSpecialChars ? 
                         password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) : true;
    bool hasMinLength = password.length >= _minPasswordLength;
    
    // Calculate strength (0-100)
    int strength = 0;
    
    if (hasMinLength) strength += 25;
    if (hasUppercase) strength += 25;
    if (hasLowercase) strength += 10;
    if (hasNumber) strength += 25;
    if (hasSpecialChar) strength += 25;
    
    // Reduce strength for short passwords
    if (password.length < 10) strength -= (10 - password.length) * 2;
    
    // Ensure strength is between 0-100
    strength = strength.clamp(0, 100);
    
    // Check if valid based on requirements
    bool isValid = hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
    
    // Collect weaknesses
    List<String> weaknesses = [];
    if (!hasMinLength) weaknesses.add('Le mot de passe doit contenir au moins $_minPasswordLength caractères');
    if (!hasUppercase) weaknesses.add('Le mot de passe doit contenir au moins une lettre majuscule');
    if (!hasLowercase) weaknesses.add('Le mot de passe doit contenir au moins une lettre minuscule');
    if (!hasNumber) weaknesses.add('Le mot de passe doit contenir au moins un chiffre');
    if (!hasSpecialChar) weaknesses.add('Le mot de passe doit contenir au moins un caractère spécial');
    
    return {
      'isValid': isValid,
      'strength': strength,
      'weaknesses': weaknesses,
    };
  }
  
  // Change password
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'Vous devez être connecté pour changer de mot de passe',
      };
    }
    
    try {
      final email = _currentUser!.email;
      final storedSalt = await _secureStorage.read(key: 'salt_$email');
      final storedHashedPassword = await _secureStorage.read(key: 'password_$email');
      
      if (storedSalt == null || storedHashedPassword == null) {
        return {
          'success': false,
          'message': 'Impossible de vérifier le mot de passe actuel',
        };
      }
      
      // Verify current password
      final hashedCurrentPassword = _hashPassword(currentPassword, storedSalt);
      if (hashedCurrentPassword != storedHashedPassword) {
        return {
          'success': false,
          'message': 'Mot de passe actuel incorrect',
        };
      }
      
      // Check new password strength
      final passwordCheck = checkPasswordStrength(newPassword);
      if (!passwordCheck['isValid']) {
        return {
          'success': false,
          'message': 'Nouveau mot de passe trop faible',
          'details': passwordCheck['weaknesses'],
        };
      }
      
      // Generate new salt and hash new password
      final newSalt = _generateSalt();
      final hashedNewPassword = _hashPassword(newPassword, newSalt);
      
      // Store new credentials
      await _secureStorage.write(key: 'password_$email', value: hashedNewPassword);
      await _secureStorage.write(key: 'salt_$email', value: newSalt);
      
      SecurityLogger.info('Password changed for user: $email');
      
      return {
        'success': true,
        'message': 'Mot de passe changé avec succès',
      };
    } catch (e) {
      SecurityLogger.error('Change password error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Une erreur est survenue lors du changement de mot de passe',
      };
    }
  }
  
  // Delete account
  Future<bool> deleteAccount(String password) async {
    if (_currentUser == null) return false;
    
    try {
      final email = _currentUser!.email;
      final storedSalt = await _secureStorage.read(key: 'salt_$email');
      final storedHashedPassword = await _secureStorage.read(key: 'password_$email');
      
      if (storedSalt == null || storedHashedPassword == null) {
        return false;
      }
      
      // Verify password
      final hashedPassword = _hashPassword(password, storedSalt);
      if (hashedPassword != storedHashedPassword) {
        return false;
      }
      
      // Delete all user data
      await _secureStorage.delete(key: 'password_$email');
      await _secureStorage.delete(key: 'salt_$email');
      await _secureStorage.delete(key: 'userdata_$email');
      await _storageService.clearUserProfile();
      
      _currentUser = null;
      notifyListeners();
      
      SecurityLogger.info('Account deleted: $email');
      
      return true;
    } catch (e) {
      SecurityLogger.error('Delete account error: ${e.toString()}');
      return false;
    }
  }