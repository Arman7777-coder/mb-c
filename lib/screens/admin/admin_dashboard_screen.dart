import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _surveys = [];
  List<dynamic> _redemptions = [];
  List<dynamic> _fraud = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ref.read(apiServiceProvider);
    try {
      _stats = await api.getAdminDashboard();
      _users = await api.getAdminUsers();
      _surveys = await api.getAdminSurveys();
      _redemptions = await api.getAdminRedemptions();
      _fraud = await api.getAdminFraud();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Users'),
            Tab(text: 'Surveys'),
            Tab(text: 'Redemptions'),
            Tab(text: 'Fraud'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(),
                _buildUsersTab(),
                _buildSurveysTab(),
                _buildRedemptionsTab(),
                _buildFraudTab(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    if (_stats == null) return const Center(child: Text('No data'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _statCard('Users', '${_stats!['total_users']}', Icons.people, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Completions', '${_stats!['total_completions']}', Icons.check_circle, AppColors.earnings)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Points Given', NumberFormat('#,###').format(_stats!['total_points_distributed']), Icons.monetization_on, AppColors.premium)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Pending', '${_stats!['pending_redemptions']}', Icons.hourglass_empty, AppColors.error)),
          ],
        ),
        const SizedBox(height: 12),
        _statCard('Flagged Users', '${_stats!['flagged_users']}', Icons.flag, AppColors.error),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final u = _users[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: u['flagged'] == true ? AppColors.error.withValues(alpha: 0.5) : AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Device: ${u['device_id'].toString().substring(0, 12)}...', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  if (u['flagged'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(4)),
                      child: const Text('FLAGGED', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (u['is_premium'] == true)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.premiumLight, borderRadius: BorderRadius.circular(4)),
                      child: const Text('PRO', style: TextStyle(color: AppColors.premium, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Balance: ${NumberFormat('#,###').format(u['balance'])} pts  |  Fraud: ${(u['fraud_score'] as num).toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSurveysTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _surveys.length,
      itemBuilder: (_, i) {
        final s = _surveys[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${s['survey_number']} ${s['title']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${s['category']} • ${s['total_completions']} completions', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: s['is_active'] == true,
                onChanged: (_) async {
                  final api = ref.read(apiServiceProvider);
                  await api.toggleSurvey(s['id']);
                  _loadData();
                },
                activeColor: AppColors.earnings,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRedemptionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _redemptions.length,
      itemBuilder: (_, i) {
        final r = _redemptions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$${(r['dollar_value'] as num).toStringAsFixed(2)} via ${r['payout_method']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  _statusBadge(r['status']),
                ],
              ),
              const SizedBox(height: 4),
              Text('Device: ${r['user_device_id']?.toString().substring(0, 12) ?? 'N/A'}...', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (r['status'] == 'pending') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reviewRedemption(r['id'], 'approved'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.earnings, side: const BorderSide(color: AppColors.earnings)),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reviewRedemption(r['id'], 'rejected'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFraudTab() {
    if (_fraud.isEmpty) {
      return const Center(child: Text('No flagged activity', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fraud.length,
      itemBuilder: (_, i) {
        final f = _fraud[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason: ${f['flag_reason']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Duration: ${f['completion_duration_seconds']}s  |  Reward: ${f['final_reward']} pts',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('Completed: ${f['completed_at']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = AppColors.premium;
        break;
      case 'approved':
        color = AppColors.earnings;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _reviewRedemption(String id, String status) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.reviewRedemption(id, status);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redemption $status'), backgroundColor: status == 'approved' ? AppColors.earnings : AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
