import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/dummy_data_service.dart';

class SmartRouteScreen extends StatelessWidget {
  const SmartRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Consumer<AppState>(
            builder: (context, state, _) {
              final crowdData = state.crowdDataList;

              // Find crowded locations and their alternatives
              final suggestions = <Map<String, dynamic>>[];
              for (final data in crowdData) {
                final suggestion = DummyDataService.suggestAlternative(
                  data.locationId,
                  crowdData,
                );
                if (suggestion != null) {
                  suggestions.add(suggestion);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Route',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI-powered crowd avoidance',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Suggestions
                  Expanded(
                    child: suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.crowdLow.withValues(
                                    alpha: 0.5,
                                  ),
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'All clear!',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No crowded locations detected right now',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final s = suggestions[index];
                              return _RouteCard(suggestion: s);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;

  const _RouteCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final savings = (suggestion['savings'] as double);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Crowded location
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.crowdHigh.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: AppColors.crowdHigh,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion['original'],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Crowd: ${(suggestion['original_density'] as double).toStringAsFixed(0)}% (HIGH)',
                      style: const TextStyle(
                        color: AppColors.crowdHigh,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Arrow
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Column(
                  children: [
                    Container(
                      width: 2,
                      height: 20,
                      color: AppColors.neonCyan.withValues(alpha: 0.3),
                    ),
                    const Icon(
                      Icons.arrow_downward,
                      color: AppColors.neonCyan,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${savings.toStringAsFixed(0)}% less crowded',
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alternative
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.crowdLow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.crowdLow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion['alternative'],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Crowd: ${(suggestion['alternative_density'] as double).toStringAsFixed(0)}% (LOW)',
                      style: const TextStyle(
                        color: AppColors.crowdLow,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
