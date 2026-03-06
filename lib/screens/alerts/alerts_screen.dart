import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/crowd_alert.dart';
import '../../constants/app_constants.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alerts',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Get notified when crowd drops',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      FloatingActionButton.small(
                        backgroundColor: AppColors.neonGreen,
                        onPressed: () => _showAddAlertDialog(context, state),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.backgroundDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Triggered alerts
                if (state.triggeredAlerts.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(14),
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
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: AppColors.neonGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Active Alerts',
                              style: TextStyle(
                                color: AppColors.neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => state.clearTriggeredAlerts(),
                              child: const Text(
                                'Dismiss',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
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
                ],

                const SizedBox(height: 8),

                // Alert list
                Expanded(
                  child: state.alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.5,
                                ),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No alerts set',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to create a crowd alert',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.alerts.length,
                          itemBuilder: (context, index) {
                            final alert = state.alerts[index];
                            return _AlertCard(
                              alert: alert,
                              onToggle: () => state.toggleAlert(alert.id),
                              onDelete: () => state.removeAlert(alert.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddAlertDialog(BuildContext context, AppState state) {
    String selectedLocation = 'metro_a';
    double threshold = 30;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Alert',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLocation,
                        dropdownColor: AppColors.surfaceDark,
                        style: const TextStyle(color: AppColors.textPrimary),
                        isExpanded: true,
                        items: AppConstants.demoLocations.map((loc) {
                          return DropdownMenuItem(
                            value: loc['id'] as String,
                            child: Text(loc['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedLocation = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Threshold
                  Text(
                    'Notify when crowd < ${threshold.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: threshold,
                    min: 10,
                    max: 80,
                    divisions: 14,
                    activeColor: AppColors.neonGreen,
                    inactiveColor: AppColors.surfaceDark,
                    label: '${threshold.toStringAsFixed(0)}%',
                    onChanged: (v) {
                      setDialogState(() => threshold = v);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final loc = AppConstants.demoLocations.firstWhere(
                          (l) => l['id'] == selectedLocation,
                        );
                        state.addAlert(
                          CrowdAlert(
                            id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
                            locationId: selectedLocation,
                            locationName: loc['name'],
                            threshold: threshold,
                            createdAt: DateTime.now(),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Create Alert'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final CrowdAlert alert;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isActive
              ? AppColors.neonGreen.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: alert.isActive
                  ? AppColors.neonGreen.withValues(alpha: 0.15)
                  : AppColors.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications,
              color: alert.isActive ? AppColors.neonGreen : AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.locationName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Notify when < ${alert.threshold.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: alert.isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.neonGreen,
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
