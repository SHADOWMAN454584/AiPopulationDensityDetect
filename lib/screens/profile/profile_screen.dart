import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<AppState, ThemeProvider>(
      builder: (context, state, themeProvider, _) {
        final user = state.currentUser;

        return Container(
          decoration: AppTheme.gradientBackgroundFor(context),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentGreen(context),
                          AppTheme.accentCyan(context),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGreen(
                            context,
                          ).withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (user?.name ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.backgroundDark
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    user?.name ?? 'User',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen(
                        context,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.isAdmin == true ? 'Admin' : 'Public User',
                      style: TextStyle(
                        color: AppTheme.accentGreen(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Theme Switcher
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accentGreen(
                          context,
                        ).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: AppTheme.accentGreen(context),
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                isDark
                                    ? 'Switch to light theme'
                                    : 'Switch to dark theme',
                                style: TextStyle(
                                  color: AppTheme.textMuted(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isDark,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeColor: AppColors.neonGreen,
                          activeTrackColor: AppColors.neonGreen.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // API Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.isApiConnected
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: state.isApiConnected
                              ? AppColors.crowdLow
                              : AppColors.crowdMedium,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backend Status',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                state.isApiConnected
                                    ? 'Connected — real-time data'
                                    : 'Offline — using demo data',
                                style: TextStyle(
                                  color: state.isApiConnected
                                      ? AppColors.crowdLow
                                      : AppColors.crowdMedium,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.isApiConnected
                                ? AppColors.crowdLow
                                : AppColors.crowdMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Menu Items
                  _ProfileMenuItem(
                    icon: Icons.schedule,
                    label: 'Best Time Predictor',
                    onTap: () => Navigator.pushNamed(context, '/best-time'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.alt_route,
                    label: 'Smart Route',
                    onTap: () => Navigator.pushNamed(context, '/smart-route'),
                  ),
                  if (user?.isAdmin == true)
                    _ProfileMenuItem(
                      icon: Icons.admin_panel_settings,
                      label: 'Admin Panel',
                      onTap: () => Navigator.pushNamed(context, '/admin'),
                    ),
                  _ProfileMenuItem(
                    icon: Icons.info_outline,
                    label: 'About CrowdSense AI',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'CrowdSense AI',
                        applicationVersion: '1.0.0',
                        children: [
                          const Text(
                            'AI-powered crowd prediction app to help you plan smarter travel.',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.logout();
                        Navigator.pushReplacementNamed(context, '/auth');
                      },
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.crowdHigh,
                      ),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(color: AppColors.crowdHigh),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.crowdHigh),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentGreen(context), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
