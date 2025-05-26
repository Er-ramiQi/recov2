import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/secure_auth_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/constants.dart';
import '../utils/api_key_manager.dart';
import 'login_screen.dart';

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
    
    // Start initialization after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      _initializeApp();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    try {
      // Initialize API key manager
      await ApiKeyManager.initializeApiKey();
      
      // Initialize services
      final storageService = Provider.of<SecureStorageService>(context, listen: false);
      await storageService.initialize();
      
      final authService = Provider.of<SecureAuthService>(context, listen: false);
      await authService.initialize();
      
      if (!mounted) return;
      
      // Navigate based on authentication status
      if (authService.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      // If anything fails during initialization, go to login screen
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
        decoration: BoxDecoration(
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
                      Icon(
                        Icons.movie,
                        size: 100,
                        color: Colors.white,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // App name
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(
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