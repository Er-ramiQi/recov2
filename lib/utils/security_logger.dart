import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel { debug, info, warning, error }

class SecurityLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kDebugMode ? Level.debug : Level.error,
  );

  // Patterns to detect sensitive information
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}',
  );
  
  static final RegExp _phonePattern = RegExp(
    r'(\+\d{1,3}[ -]?)?\(?\d{3}\)?[ -]?\d{3}[ -]?\d{4}',
  );

  // List of sensitive terms to redact
  static final List<String> _sensitiveTerms = [
    'password', 'token', 'auth', 'key', 'secret', 'credential', 'api_key',
    'credit', 'card', 'cvv', 'expiry', 'ssn', 'social', 'security',
  ];

  // Sanitize log messages to remove sensitive information
  static String _sanitizeMessage(String message) {
    String sanitized = message;
    
    // Replace emails
    sanitized = sanitized.replaceAllMapped(_emailPattern, (match) => '<EMAIL>');
    
    // Replace phone numbers
    sanitized = sanitized.replaceAllMapped(_phonePattern, (match) => '<PHONE>');
    
    // Replace sensitive terms
    for (final term in _sensitiveTerms) {
      final RegExp pattern = RegExp(
        r'(' + term + r'[\s]*[=:]\s*["\']?)([^"\',\s]+)(["\']?)',
        caseSensitive: false,
      );
      
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        return '${match.group(1)}<REDACTED>${match.group(3) ?? ''}';
      });
    }
    
    return sanitized;
  }

  // Debug level logging
  static void debug(String message) {
    if (kDebugMode) {
      final sanitized = _sanitizeMessage(message);
      _logger.d(sanitized);
      _writeToFile(LogLevel.debug, sanitized);
    }
  }

  // Info level logging
  static void info(String message) {
    final sanitized = _sanitizeMessage(message);
    _logger.i(sanitized);
    _writeToFile(LogLevel.info, sanitized);
  }

  // Warning level logging
  static void warn(String message) {
    final sanitized = _sanitizeMessage(message);
    _logger.w(sanitized);
    _writeToFile(LogLevel.warning, sanitized);
  }

  // Error level logging
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    final sanitized = _sanitizeMessage(message);
    if (error != null) {
      _logger.e(sanitized, error: error, stackTrace: stackTrace);
    } else {
      _logger.e(sanitized);
    }
    _writeToFile(LogLevel.error, sanitized);
  }

  // Write logs to file for persistence
  static Future<void> _writeToFile(LogLevel level, String message) async {
    if (!kDebugMode) return; // Only write to file in debug mode
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd');
      final fileName = '${formatter.format(now)}_app.log';
      final file = File('$path/$fileName');
      
      // Create file if it doesn't exist
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      
      // Format log entry
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
      final levelStr = level.toString().split('.').last.toUpperCase();
      final logEntry = '[$timestamp] $levelStr: $message\n';
      
      // Append to file
      await file.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      // Don't use logging here to avoid recursion
      if (kDebugMode) {
        print('Failed to write log to file: $e');
      }
    }
  }
  
  // Clear old log files (keeping a certain number of days)
  static Future<void> cleanupLogs({int keepDays = 7}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final logDir = Directory(path);
      
      final files = await logDir.list().where((entity) {
        return entity is File && 
               entity.path.endsWith('.log') && 
               entity.path.contains(RegExp(r'\d{4}-\d{2}-\d{2}_app\.log'));
      }).toList();
      
      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd');
      
      for (var entity in files) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          final dateStr = fileName.split('_').first;
          
          try {
            final fileDate = formatter.parse(dateStr);
            final difference = now.difference(fileDate).inDays;
            
            if (difference > keepDays) {
              await entity.delete();
            }
          } catch (e) {
            // Skip files with invalid date format
            continue;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clean up logs: $e');
      }
    }
  }
}