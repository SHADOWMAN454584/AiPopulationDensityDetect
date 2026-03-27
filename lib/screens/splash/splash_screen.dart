import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;
  bool _isInitializing = true;
  String _statusMessage = 'Connecting to backend...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeIn = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    // Initialize app state and then navigate
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize the AppState (connects to backend, loads locations)
      final appState = context.read<AppState>();
      await appState.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = appState.isApiConnected
              ? 'Backend connected!'
              : 'Using offline mode';
        });
      }

      // Wait a moment to show the status, then navigate
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Using offline mode';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF2A1B3D)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.scale(scale: _scaleAnim.value, child: child),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI Brain + Map Pin Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.neonGreen, AppColors.neonCyan],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonGreen.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_alt,
                      size: 60,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // App Name
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.neonGreen, AppColors.neonCyan],
                    ).createShader(bounds),
                    child: const Text(
                      'CrowdSense AI',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated Tagline
                  SizedBox(
                    height: 30,
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w300,
                      ),
                      child: AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Predict Before You Step Out',
                            speed: const Duration(milliseconds: 80),
                          ),
                        ],
                        isRepeatingAnimation: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Connection status
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Row(
                      key: ValueKey(_statusMessage),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isInitializing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.neonCyan,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            _statusMessage.contains('connected')
                                ? Icons.check_circle
                                : Icons.cloud_off,
                            color: _statusMessage.contains('connected')
                                ? AppColors.neonGreen
                                : AppColors.textSecondary,
                            size: 16,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: _statusMessage.contains('connected')
                                ? AppColors.neonGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Neural network dots animation
                  _buildNeuralDots(),

                  const SizedBox(height: 80),

                  // Get Started Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/auth');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonGreen,
                      foregroundColor: AppColors.backgroundDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.neonGreen.withValues(alpha: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeuralDots() {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 200)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonCyan.withValues(alpha: value),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonCyan.withValues(alpha: value * 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
