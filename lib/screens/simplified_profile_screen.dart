import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_preferences.dart';
import '../services/secure_auth_service.dart';
import '../services/local_storage_service.dart';
import '../utils/constants.dart';
import '../utils/security_logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SecureAuthService _authService;
  late LocalStorageService _storageService;
  UserPreferences? _userPreferences;
  bool _isLoading = true;
  bool _isEditing = false;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  final List<String> _availableGenres = [
    'Action', 'Aventure', 'Animation', 'Comédie', 'Crime',
    'Documentaire', 'Drame', 'Famille', 'Fantastique', 'Histoire',
    'Horreur', 'Musique', 'Mystère', 'Romance', 'Science-Fiction',
    'Thriller', 'Guerre', 'Western'
  ];

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<SecureAuthService>(context, listen: false);
    _storageService = Provider.of<LocalStorageService>(context, listen: false);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await _storageService.getUserPreferences();

      if (mounted) {
        setState(() {
          _userPreferences = prefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      SecurityLogger.error('Error loading user preferences: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppConstants.genericErrorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _startEditing() {
    final user = _authService.currentUser;
    if (user == null) return;
    
    setState(() {
      _isEditing = true;
      _usernameController.text = user.username;
      _bioController.text = user.bio ?? '';
    });
  }

  Future<void> _saveProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.updateProfile(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppConstants.genericErrorMessage),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      SecurityLogger.error('Profile update error: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppConstants.genericErrorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    if (_userPreferences == null) return;
    
    await _storageService.setDarkModePreference(value);
    await _loadUserData();
  }

  Future<void> _updateGenrePreferences(List<String> genres) async {
    if (_userPreferences == null) return;
    
    await _storageService.updatePreferredGenres(genres);
    await _loadUserData();
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Se déconnecter'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                } catch (e) {
                  SecurityLogger.error('Logout error: ${e.toString()}');
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erreur lors de la déconnexion'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vous n\'êtes pas connecté',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _isEditing
              ? _buildEditProfileForm(user)
              : _buildProfileContent(user, isDarkMode),
    );
  }

  Widget _buildProfileContent(dynamic user, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.primaryDark : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Profile Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.bio!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit),
              label: const Text('Modifier le profil'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          
          // Preferences Section
          const Text(
            'Préférences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Dark Mode Toggle
          SwitchListTile(
            title: const Text('Mode sombre'),
            subtitle: const Text('Changer l\'apparence de l\'application'),
            value: _userPreferences?.darkMode ?? true,
            onChanged: _toggleDarkMode,
            secondary: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.accent,
            ),
          ),
          
          const Divider(),
          
          // Genres Section
          const Text(
            'Genres préférés',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Genre Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableGenres.map((genre) {
              final isSelected = 
                  _userPreferences?.preferredGenres.contains(genre) ?? false;
              return FilterChip(
                label: Text(genre),
                selected: isSelected,
                onSelected: (selected) {
                  List<String> updatedGenres = List.from(_userPreferences?.preferredGenres ?? []);
                  if (selected) {
                    updatedGenres.add(genre);
                  } else {
                    updatedGenres.remove(genre);
                  }
                  _updateGenrePreferences(updatedGenres);
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Go to Recommendations
          ListTile(
            leading: const Icon(Icons.recommend, color: AppColors.accent),
            title: const Text('Voir mes recommandations'),
            subtitle: const Text('Basées sur vos genres préférés'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/recommendations');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileForm(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modifier le profil',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Username field
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bio field
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.info_outline),
              hintText: 'Parlez-nous de vous...',
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}