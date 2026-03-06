import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/crowd_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final user = state.currentUser;
        final crowdData = state.crowdDataList;
        final isLoading = state.isLoading;

        return Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => state.refreshCrowdData(),
              color: AppColors.neonGreen,
              child: CustomScrollView(
                slivers: [
                  // Greeting
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.psychology_alt,
                              color: AppColors.neonGreen,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _QuickAction(
                            icon: Icons.schedule,
                            label: 'Best Time',
                            color: AppColors.neonCyan,
                            onTap: () =>
                                Navigator.pushNamed(context, '/best-time'),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.alt_route,
                            label: 'Smart Route',
                            color: AppColors.neonPurple,
                            onTap: () =>
                                Navigator.pushNamed(context, '/smart-route'),
                          ),
                          const SizedBox(width: 12),
                          if (user?.isAdmin == true)
                            _QuickAction(
                              icon: Icons.admin_panel_settings,
                              label: 'Admin',
                              color: AppColors.crowdHigh,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/admin'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Live Crowd Status',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: state.isApiConnected
                                    ? AppColors.neonGreen
                                    : AppColors.crowdMedium,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                state.isApiConnected ? 'Live' : 'Demo',
                                style: TextStyle(
                                  color: state.isApiConnected
                                      ? AppColors.neonGreen
                                      : AppColors.crowdMedium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Crowd Cards
                  if (isLoading)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.neonGreen,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final data = crowdData[index];
                        return _CrowdCard(
                          data: data,
                          onTap: () {
                            state.selectLocation(data.locationId);
                          },
                        );
                      }, childCount: crowdData.length),
                    ),

                  // Triggered Alerts Banner
                  if (state.triggeredAlerts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.neonGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.neonGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.notifications_active,
                                  color: AppColors.neonGreen,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Alert Triggered!',
                                  style: TextStyle(
                                    color: AppColors.neonGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...state.triggeredAlerts.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  a['message'],
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrowdCard extends StatelessWidget {
  final CrowdData data;
  final VoidCallback onTap;

  const _CrowdCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(data.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Density Gauge
            CircularPercentIndicator(
              radius: 35,
              lineWidth: 6,
              percent: data.crowdDensity / 100,
              center: Text(
                '${data.crowdDensity.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              progressColor: statusColor,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.locationName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.crowdCount} people',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Prediction
            if (data.predictedNextHour != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Next Hour',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.predictedNextHour! > data.crowdDensity
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: data.predictedNextHour! > data.crowdDensity
                            ? AppColors.crowdHigh
                            : AppColors.crowdLow,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.predictedNextHour!.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getStatusColor(
                            CrowdData.getStatusFromDensity(
                              data.predictedNextHour!,
                            ),
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'low':
        return AppColors.crowdLow;
      case 'medium':
        return AppColors.crowdMedium;
      case 'high':
        return AppColors.crowdHigh;
      default:
        return AppColors.textMuted;
    }
  }
}
