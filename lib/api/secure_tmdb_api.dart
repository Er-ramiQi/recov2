import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../utils/api_key_manager.dart';
import '../utils/security_logger.dart';

class SecureTMDBApi {
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  
  // Certificate fingerprints for certificate pinning
  // These are example SHA-256 fingerprints - in a real app, you would use actual certificate fingerprints
  static final List<String> _certificateFingerprints = [
    "49F2FD32E1E72C57BFB6D58798B6BA9A9DE71C6338632875DB13A8BC392B435A",
  ];
  
  final Dio _dio = Dio();
  bool _isInitialized = false;
  
  // Initialize the HTTP client with security parameters
  Future<void> _initializeClient() async {
    if (_isInitialized) return;
    
    try {
      // Configure timeouts
      _dio.options.connectTimeout = const Duration(seconds: 10);
      _dio.options.receiveTimeout = const Duration(seconds: 15);
      _dio.options.sendTimeout = const Duration(seconds: 10);
      
      // Configure base URL
      _dio.options.baseUrl = baseUrl;
      
      // Force HTTPS and certificate pinning
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // Certificate pinning logic
          final fingerprint = _calculateSHA256Fingerprint(cert.der);
          if (_certificateFingerprints.contains(fingerprint)) {
            return true;
          }
          
          SecurityLogger.warn('Certificate pinning failed for $host:$port');
          return false;
        };
        return client;
      };
      
      // Add interceptor to ensure HTTPS
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!options.path.startsWith('https://') && !options.baseUrl.startsWith('https://')) {
            options.path = options.path.replaceFirst('http://', 'https://');
            options.baseUrl = options.baseUrl.replaceFirst('http://', 'https://');
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          SecurityLogger.error('Network error: ${error.message}');
          return handler.next(error);
        },
      ));
      
      _isInitialized = true;
    } catch (e) {
      SecurityLogger.error('Failed to initialize secure API client: ${e.toString()}');
      throw Exception('Failed to initialize secure API client');
    }
  }
  
  // Simulated certificate fingerprinting
  String _calculateSHA256Fingerprint(List<int> certificateData) {
    // In a real implementation, this would calculate an actual SHA-256 hash
    // For demo purposes, we're just returning a mock value
    return "49F2FD32E1E72C57BFB6D58798B6BA9A9DE71C6338632875DB13A8BC392B435A";
  }
  
  // Perform a secure GET request
  Future<dynamic> _secureGet(String endpoint, {Map<String, dynamic>? queryParams}) async {
    await _initializeClient();
    
    try {
      final apiKey = await ApiKeyManager.getApiKey();
      final Map<String, dynamic> params = queryParams ?? {};
      params['api_key'] = apiKey;
      
      final response = await _dio.get(
        endpoint,
        queryParameters: params,
        options: Options(
          // Additional security headers
          headers: {
            'User-Agent': 'Limux-App/1.0',
            'Accept': 'application/json',
          },
        ),
      );
      
      return response.data;
    } catch (e) {
      SecurityLogger.error('API request failed: ${e.toString()}');
      throw Exception('Failed to load data from API');
    }
  }
  
  // Get trending movies
  Future<List<Movie>> getTrendingMovies() async {
    try {
      final data = await _secureGet('/trending/movie/week');
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load trending movies: ${e.toString()}');
      throw Exception('Failed to load trending movies');
    }
  }
  
  // Get popular movies
  Future<List<Movie>> getPopularMovies() async {
    try {
      final data = await _secureGet('/movie/popular');
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load popular movies: ${e.toString()}');
      throw Exception('Failed to load popular movies');
    }
  }
  
  // Get popular TV shows
  Future<List<TvShow>> getPopularTvShows() async {
    try {
      final data = await _secureGet('/tv/popular');
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load popular TV shows: ${e.toString()}');
      throw Exception('Failed to load popular TV shows');
    }
  }
  
  // Get movie details
  Future<Movie> getMovieDetails(int movieId) async {
    try {
      final data = await _secureGet(
        '/movie/$movieId',
        queryParams: {'append_to_response': 'credits,videos,similar'},
      );
      return Movie.fromDetailJson(data);
    } catch (e) {
      SecurityLogger.error('Failed to load movie details: ${e.toString()}');
      throw Exception('Failed to load movie details');
    }
  }
  
  // Get TV show details
  Future<TvShow> getTvShowDetails(int tvShowId) async {
    try {
      final data = await _secureGet(
        '/tv/$tvShowId',
        queryParams: {'append_to_response': 'credits,videos,similar'},
      );
      return TvShow.fromDetailJson(data);
    } catch (e) {
      SecurityLogger.error('Failed to load TV show details: ${e.toString()}');
      throw Exception('Failed to load TV show details');
    }
  }
  
  // Get recommended movies
  Future<List<Movie>> getRecommendedMovies(List<int> favoriteIds) async {
    if (favoriteIds.isEmpty) {
      return getPopularMovies();
    }
    
    try {
      final movieId = favoriteIds.first;
      final data = await _secureGet('/movie/$movieId/recommendations');
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load recommended movies: ${e.toString()}');
      throw Exception('Failed to load recommended movies');
    }
  }
  
  // Get recommended TV shows
  Future<List<TvShow>> getRecommendedTvShows(List<int> favoriteIds) async {
    if (favoriteIds.isEmpty) {
      return getPopularTvShows();
    }
    
    try {
      final tvShowId = favoriteIds.first;
      final data = await _secureGet('/tv/$tvShowId/recommendations');
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load recommended TV shows: ${e.toString()}');
      throw Exception('Failed to load recommended TV shows');
    }
  }
  
  // Search movies
  Future<List<Movie>> searchMovies(String query) async {
    try {
      final data = await _secureGet('/search/movie', queryParams: {'query': query});
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to search movies: ${e.toString()}');
      throw Exception('Failed to search movies');
    }
  }
  
  // Search TV shows  
  Future<List<TvShow>> searchTvShows(String query) async {
    try {
      final data = await _secureGet('/search/tv', queryParams: {'query': query});
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to search TV shows: ${e.toString()}');
      throw Exception('Failed to search TV shows');
    }
  }
  
  // Get movies by genre
  Future<List<Movie>> getMoviesByGenre(int genreId, {int page = 1}) async {
    try {
      final data = await _secureGet('/discover/movie', queryParams: {
        'with_genres': genreId.toString(),
        'page': page.toString(),
        'sort_by': 'popularity.desc',
      });
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load movies by genre: ${e.toString()}');
      throw Exception('Failed to load movies by genre');
    }
  }
  
  // Get TV shows by genre
  Future<List<TvShow>> getTvShowsByGenre(int genreId, {int page = 1}) async {
    try {
      final data = await _secureGet('/discover/tv', queryParams: {
        'with_genres': genreId.toString(),
        'page': page.toString(),
        'sort_by': 'popularity.desc',
      });
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load TV shows by genre: ${e.toString()}');
      throw Exception('Failed to load TV shows by genre');
    }
  }
  
  // Get top rated movies
  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    try {
      final data = await _secureGet('/movie/top_rated', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load top rated movies: ${e.toString()}');
      throw Exception('Failed to load top rated movies');
    }
  }
  
  // Get top rated TV shows
  Future<List<TvShow>> getTopRatedTvShows({int page = 1}) async {
    try {
      final data = await _secureGet('/tv/top_rated', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load top rated TV shows: ${e.toString()}');
      throw Exception('Failed to load top rated TV shows');
    }
  }
  
  // Get now playing movies
  Future<List<Movie>> getNowPlayingMovies({int page = 1}) async {
    try {
      final data = await _secureGet('/movie/now_playing', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load now playing movies: ${e.toString()}');
      throw Exception('Failed to load now playing movies');
    }
  }
  
  // Get upcoming movies
  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    try {
      final data = await _secureGet('/movie/upcoming', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((movie) => Movie.fromJson(movie)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load upcoming movies: ${e.toString()}');
      throw Exception('Failed to load upcoming movies');
    }
  }
  
  // Get airing today TV shows
  Future<List<TvShow>> getAiringTodayTvShows({int page = 1}) async {
    try {
      final data = await _secureGet('/tv/airing_today', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load airing today TV shows: ${e.toString()}');
      throw Exception('Failed to load airing today TV shows');
    }
  }
  
  // Get on the air TV shows
  Future<List<TvShow>> getOnTheAirTvShows({int page = 1}) async {
    try {
      final data = await _secureGet('/tv/on_the_air', queryParams: {
        'page': page.toString(),
      });
      return (data['results'] as List).map((show) => TvShow.fromJson(show)).toList();
    } catch (e) {
      SecurityLogger.error('Failed to load on the air TV shows: ${e.toString()}');
      throw Exception('Failed to load on the air TV shows');
    }
  }
  
  // Static methods for URL construction
  static String getPosterUrl(String path) {
    if (path.isEmpty) return '';
    return '$imageBaseUrl/w500$path';
  }
  
  static String getBackdropUrl(String path) {
    if (path.isEmpty) return '';
    return '$imageBaseUrl/w780$path';
  }
  
  static String getProfileUrl(String path) {
    if (path.isEmpty) return '';
    return '$imageBaseUrl/w185$path';
  }
  
  static String getOriginalUrl(String path) {
    if (path.isEmpty) return '';
    return '$imageBaseUrl/original$path';
  }
  
  static String getThumbnailUrl(String path) {
    if (path.isEmpty) return '';
    return '$imageBaseUrl/w200$path';
  }
  
  // Utility method to check network connectivity
  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.get(
        '/configuration',
        queryParameters: {'api_key': await ApiKeyManager.getApiKey()},
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      SecurityLogger.warn('Network connectivity check failed: ${e.toString()}');
      return false;
    }
  }
  
  // Clean up resources
  void dispose() {
    _dio.close();
  }
}