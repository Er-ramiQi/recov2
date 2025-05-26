import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/secure_auth_service.dart';
import '../utils/constants.dart';
import '../utils/security_logger.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'recommendations_screen.dart';
import 'simplified_profile_screen.dart';
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const RecommendationsScreen(),
    const ProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Check authentication status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _checkAuthentication() {
    final authService = Provider.of<SecureAuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      SecurityLogger.info('Unauthorized access attempt to main navigation');
      // Navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Animation when changing tabs
            if (index != _currentIndex) {
              _animationController.forward(from: 0.0).then((_) {
                setState(() {
                  _currentIndex = index;
                  _pageController.jumpToPage(index);
                });
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favoris',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.recommend),
              label: 'Pour vous',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}