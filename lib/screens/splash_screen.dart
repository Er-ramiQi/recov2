import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/secure_auth_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/constants.dart';
import '../utils/api_key_manager.dart';
import '../utils/security_logger.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _animationController.forward();
    
    // Attendre un peu pour l'animation, puis initialiser
    Future.delayed(const Duration(milliseconds: 800), () {
      _initializeApp();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    SecurityLogger.info('=== APP INITIALIZATION ===');
    
    try {
      // 1. Initialiser l'API key manager
      SecurityLogger.info('Initializing API key manager...');
      await ApiKeyManager.initializeApiKey();
      
      // 2. Initialiser le service de stockage
      SecurityLogger.info('Initializing storage service...');
      final storageService = Provider.of<SecureStorageService>(context, listen: false);
      await storageService.initialize();
      
      // 3. Initialiser le service d'authentification
      SecurityLogger.info('Initializing auth service...');
      final authService = Provider.of<SecureAuthService>(context, listen: false);
      await authService.initialize();
      
      if (!mounted) return;
      
      // 4. Naviguer selon l'état d'authentification
      SecurityLogger.info('Checking authentication status...');
      SecurityLogger.info('Is authenticated: ${authService.isAuthenticated}');
      SecurityLogger.info('Current user: ${authService.currentUser?.email}');
      
      // Attendre un peu pour que l'animation se termine
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      if (authService.isAuthenticated) {
        SecurityLogger.info('User is authenticated, navigating to main screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      } else {
        SecurityLogger.info('User not authenticated, navigating to login screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      
    } catch (e) {
      SecurityLogger.error('App initialization failed: ${e.toString()}');
      
      // En cas d'erreur, aller à l'écran de connexion
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo
                      const Icon(
                        Icons.movie,
                        size: 100,
                        color: Colors.white,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // App name
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Loading indicator
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Loading text
                      const Text(
                        'Initialisation...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}