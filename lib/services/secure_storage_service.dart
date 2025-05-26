import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/user_profile.dart';
import '../utils/security_logger.dart';

class SecureStorageService {
  // Constants for storage keys
  static const String _prefsKey = 'user_preferences_encrypted';
  static const String _profileKey = 'user_profile_encrypted';
  static const String _encryptionKeyKey = 'encryption_key';

  // Options for Android secure storage
  final _secureStorageOptions = const AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  // The secure storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // In-memory cache to reduce reads from secure storage
  final Map<String, String> _cache = {};

  // Initialization method
  Future<void> initialize() async {
    try {
      // Check if an encryption key exists, if not, create one
      await _ensureEncryptionKeyExists();
    } catch (e) {
      SecurityLogger.error('Failed to initialize secure storage: ${e.toString()}');
      rethrow;
    }
  }

  // Ensures an encryption key exists in secure storage
  Future<void> _ensureEncryptionKeyExists() async {
    try {
      final existingKey = await _secureStorage.read(
        key: _encryptionKeyKey,
        aOptions: _secureStorageOptions,
      );

      if (existingKey == null) {
        // Generate a new encryption key
        final key = encrypt.Key.fromSecureRandom(32).base64;
        await _secureStorage.write(
          key: _encryptionKeyKey,
          value: key,
          aOptions: _secureStorageOptions,
        );
      }
    } catch (e) {
      SecurityLogger.error('Error ensuring encryption key exists');
      rethrow;
    }
  }

  // Gets the encryption key from secure storage
  Future<String> _getEncryptionKey() async {
    try {
      final key = await _secureStorage.read(
        key: _encryptionKeyKey,
        aOptions: _secureStorageOptions,
      );
      if (key == null) {
        throw Exception('Encryption key not found');
      }
      return key;
    } catch (e) {
      SecurityLogger.error('Error retrieving encryption key');
      rethrow;
    }
  }

  // Encrypts data using AES
  Future<String> _encrypt(String data) async {
    try {
      final keyMaterial = await _getEncryptionKey();
      final key = encrypt.Key.fromBase64(keyMaterial);
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(data, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      SecurityLogger.error('Encryption error');
      throw Exception('Failed to encrypt data');
    }
  }

  // Decrypts data using AES
  Future<String> _decrypt(String encryptedData) async {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid encrypted data format');
      }

      final keyMaterial = await _getEncryptionKey();
      final key = encrypt.Key.fromBase64(keyMaterial);
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      SecurityLogger.error('Decryption error');
      throw Exception('Failed to decrypt data');
    }
  }

  // Save user profile securely
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final json = profile.serialize();
      final encrypted = await _encrypt(json);
      
      await _secureStorage.write(
        key: _profileKey,
        value: encrypted,
        aOptions: _secureStorageOptions,
      );
      // Update cache
      _cache[_profileKey] = json;
    } catch (e) {
      SecurityLogger.error('Error saving user profile: ${e.toString()}');
      throw Exception('Failed to save user profile');
    }
  }

  // Get user profile securely
  Future<UserProfile?> getUserProfile() async {
    try {
      // Try to get from cache first
      if (_cache.containsKey(_profileKey)) {
        return UserProfile.deserialize(_cache[_profileKey]!);
      }

      // Read from secure storage
      final encrypted = await _secureStorage.read(
        key: _profileKey,
        aOptions: _secureStorageOptions,
      );
      
      if (encrypted == null) {
        return null;
      }
      
      final decrypted = await _decrypt(encrypted);
      _cache[_profileKey] = decrypted;
      
      return UserProfile.deserialize(decrypted);
    } catch (e) {
      SecurityLogger.error('Error retrieving user profile: ${e.toString()}');
      return null;
    }
  }

  // Clear user profile
  Future<void> clearUserProfile() async {
    try {
      await _secureStorage.delete(
        key: _profileKey,
        aOptions: _secureStorageOptions,
      );
      _cache.remove(_profileKey);
    } catch (e) {
      SecurityLogger.error('Error clearing user profile');
      rethrow;
    }
  }

  // Save user preferences securely (JSON serializable data)
  Future<void> saveData(String key, Map<String, dynamic> data) async {
    try {
      final jsonData = jsonEncode(data);
      final encrypted = await _encrypt(jsonData);
      
      await _secureStorage.write(
        key: '${key}_encrypted',
        value: encrypted,
        aOptions: _secureStorageOptions,
      );
      
      _cache[key] = jsonData;
    } catch (e) {
      SecurityLogger.error('Error saving data for key $key');
      rethrow;
    }
  }

  // Get user preferences securely
  Future<Map<String, dynamic>?> getData(String key) async {
    try {
      // Try to get from cache first
      if (_cache.containsKey(key)) {
        return jsonDecode(_cache[key]!);
      }

      // Read from secure storage
      final encrypted = await _secureStorage.read(
        key: '${key}_encrypted',
        aOptions: _secureStorageOptions,
      );
      
      if (encrypted == null) {
        return null;
      }
      
      final decrypted = await _decrypt(encrypted);
      _cache[key] = decrypted;
      
      return jsonDecode(decrypted);
    } catch (e) {
      SecurityLogger.error('Error retrieving data for key $key');
      return null;
    }
  }

  // Clear all stored data
  Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll(aOptions: _secureStorageOptions);
      _cache.clear();
      // Recreate encryption key
      await _ensureEncryptionKeyExists();
    } catch (e) {
      SecurityLogger.error('Error clearing all data');
      rethrow;
    }
  }
}