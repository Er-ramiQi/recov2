import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/tv_show_detail_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/simplified_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/secure_auth_service.dart';

// Application routes configuration
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String movieDetail = '/movie_detail';
  static const String tvShowDetail = '/tv_show_detail';
  static const String favorites = '/favorites';
  static const String recommendations = '/recommendations';
  static const String profile = '/profile';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
        
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
        
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      
      case home:
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return const HomeScreen();
          },
        );
      
      case movieDetail:
        // Verify the argument is an int (movie ID)
        if (settings.arguments is! int) {
          return _errorRoute('Invalid movie ID');
        }
        
        final int movieId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return MovieDetailScreen(movieId: movieId);
          },
        );
      
      case tvShowDetail:
        // Verify the argument is an int (TV show ID)
        if (settings.arguments is! int) {
          return _errorRoute('Invalid TV show ID');
        }
        
        final int tvShowId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return TVShowDetailScreen(showId: tvShowId);
          },
        );
      
      case favorites:
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return const FavoritesScreen();
          },
        );
      
      case recommendations:
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return const RecommendationsScreen();
          },
        );
      
      case profile:
        return MaterialPageRoute(
          builder: (context) {
            // Check if user is authenticated, if not redirect to login
            final authService = Provider.of<SecureAuthService>(context, listen: false);
            if (!authService.isAuthenticated) {
              return const LoginScreen();
            }
            return const ProfileScreen();
          },
        );
      
      default:
        // Default route in case of error
        return _errorRoute('Route not found: ${settings.name}');
    }
  }
  
  // Error route
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(_).pushReplacementNamed(home);
                  },
                  child: const Text('Retour à l\'accueil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}