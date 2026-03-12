import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChildProfileDashboard extends StatefulWidget {
  final String childId;
  final String viewerRole; // 'hcw', 'parent', 'teacher'

  const ChildProfileDashboard({
    super.key,
    required this.childId,
    required this.viewerRole,
  });

  @override
  State<ChildProfileDashboard> createState() => _ChildProfileDashboardState();
}

class _ChildProfileDashboardState extends State<ChildProfileDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _getTabsForRole(widget.viewerRole);
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _getTabsForRole(String role) {
    switch (role) {
      case 'hcw':
        return ['Overview', 'Screening History', 'Referrals', 'Notes'];
      case 'teacher':
        return ['Overview', 'Classroom Observations'];
      case 'parent':
      default:
        return ['Overview', 'History & Speech'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Child Profile', style: AppTheme.heading2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show role-specific actions (e.g., Unlink child, Edit profile)
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryTeal,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryPale,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('L', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liam Smith',
                        style: AppTheme.heading1.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2 years, 4 months • Male',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      // Risk Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'High Risk',
                          style: AppTheme.caption.copyWith(color: AppTheme.accentCoral, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerColor),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTabView(tab)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(String tabName) {
    switch (tabName) {
      case 'Overview':
        return _buildOverviewTab();
      case 'Screening History':
        return _buildScreeningHistoryTab();
      case 'Referrals':
        return _buildReferralsTab();
      case 'Notes':
        return _buildNotesTab();
      case 'Classroom Observations':
        return const Center(child: Text("Teacher Observations..."));
      case 'History & Speech':
        return const Center(child: Text("Parent History & Speech Games..."));
      default:
        return Center(child: Text(tabName));
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('Parent/Guardian'),
        _buildInfoTile(Icons.person, 'Sarah Smith', 'sarah.smith@example.com\n+1 555-0198'),
        const SizedBox(height: 24),
        
        _buildSectionTitle('Medical History'),
        _buildInfoTile(Icons.medical_services, 'Previous Concerns', 'Premature birth (34 weeks).\nRecurrent ear infections at 12m.'),
        const SizedBox(height: 24),

        if (widget.viewerRole == 'hcw') ...[
          _buildSectionTitle('Linked Professionals'),
          _buildInfoTile(Icons.school, 'Ms. Johnson', 'Kindergarten Teacher\nSpringfield Elementary'),
        ]
      ],
    );
  }

  Widget _buildScreeningHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHistoryCard(
          date: 'Oct 12, 2024',
          title: 'HCW Initial Screening',
          subtitle: 'Score: 18/30 • Clinical Flags Detected',
          riskLevel: 'High',
        ),
        const SizedBox(height: 16),
        _buildHistoryCard(
          date: 'Sep 05, 2024',
          title: 'Parent Questionnaire',
          subtitle: 'Score: 12/30 • Routine Home Check',
          riskLevel: 'Medium',
        ),
      ],
    );
  }

  Widget _buildReferralsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Referrals', style: AppTheme.heading2),
            TextButton.icon(
              onPressed: () {}, 
              icon: const Icon(Icons.add, size: 18), 
              label: const Text('NEW')
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audiology Referral', style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('PENDING', style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Generated automatically on Oct 12, 2024 based on High Risk screening.', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {}, 
                icon: const Icon(Icons.picture_as_pdf), 
                label: const Text('VIEW PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: const BorderSide(color: AppTheme.primaryTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    return const Center(child: Text("Clinical Notes Viewer"));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: AppTheme.heading2),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryTeal),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard({required String date, required String title, required String subtitle, required String riskLevel}) {
    Color riskColor;
    if (riskLevel == 'High') {
      riskColor = AppTheme.accentCoral;
    } else if (riskLevel == 'Medium') {
      riskColor = const Color(0xFFF2994A); // Orange
    } else {
      riskColor = AppTheme.accentGreen;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.history, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: riskColor),
          )
        ],
      ),
    );
  }
}
