import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'security_logger.dart';

class ApiKeyManager {
  static const String _apiKeyStorageKey = 'tmdb_api_key';
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // The obfuscated API key - original key is e747e5245d83d51e158ee925031ff90d
  static final List<int> _obfuscatedKey = [
    101, 55, 52, 55, 101, 53, 50, 52, 53, 100,
    56, 51, 100, 53, 49, 101, 49, 53, 56, 101,
    101, 57, 50, 53, 48, 51, 49, 102, 102, 57, 48, 100
  ];
  
  // Deobfuscates the API key
  static String _deobfuscateKey() {
    return String.fromCharCodes(_obfuscatedKey);
  }
  
  // Initialize the API key in secure storage
  static Future<void> initializeApiKey() async {
    try {
      final storedKey = await _secureStorage.read(key: _apiKeyStorageKey);
      
      // If key isn't already stored, store the deobfuscated key
      if (storedKey == null) {
        await _secureStorage.write(
          key: _apiKeyStorageKey,
          value: _deobfuscateKey(),
        );
      }
    } catch (e) {
      SecurityLogger.error('Error initializing API key: ${e.toString()}');
      // If we fail to store in secure storage, we'll fall back to the obfuscated key
    }
  }
  
  // Get the API key securely
  static Future<String> getApiKey() async {
    try {
      // Check first if the key is stored
      final storedKey = await _secureStorage.read(key: _apiKeyStorageKey);
      if (storedKey != null) {
        return storedKey;
      }
      
      // If the key is not stored, initialize it
      await initializeApiKey();
      return await _secureStorage.read(key: _apiKeyStorageKey) ?? _deobfuscateKey();
    } catch (e) {
      SecurityLogger.error('Error retrieving API key');
      // Fall back to the deobfuscated key if there's an issue
      return _deobfuscateKey();
    }
  }
  
  // Rotate API key (in a real app, this would fetch a new key from a backend)
  static Future<bool> rotateApiKey(String newKey) async {
    try {
      await _secureStorage.write(
        key: _apiKeyStorageKey,
        value: newKey,
      );
      return true;
    } catch (e) {
      SecurityLogger.error('Error rotating API key');
      return false;
    }
  }
  
  // Clear the stored API key
  static Future<void> clearApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } catch (e) {
      SecurityLogger.error('Error clearing API key');
    }
  }
}