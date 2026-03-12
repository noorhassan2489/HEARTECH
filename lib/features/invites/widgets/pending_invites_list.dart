import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PendingInvite {
  final String id;
  final String childName;
  final String parentName;
  final String riskLevel; // "Low", "Medium", "High"
  final DateTime dateSent;

  PendingInvite({
    required this.id,
    required this.childName,
    required this.parentName,
    required this.riskLevel,
    required this.dateSent,
  });
}

class PendingInvitesList extends StatelessWidget {
  final List<PendingInvite> invites;
  final Future<void> Function(String inviteId, bool accept) onRespond;

  const PendingInvitesList({
    super.key,
    required this.invites,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pending Invites (${invites.length})",
          style: AppTheme.heading2,
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: invites.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return _InviteCard(
              invite: invite,
              onRespond: (accept) => onRespond(invite.id, accept),
            );
          },
        ),
      ],
    );
  }
}

class _InviteCard extends StatefulWidget {
  final PendingInvite invite;
  final Future<void> Function(bool accept) onRespond;

  const _InviteCard({required this.invite, required this.onRespond});

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _isLoading = false;

  Future<void> _handleRespond(bool accept) async {
    setState(() => _isLoading = true);
    try {
      await widget.onRespond(accept);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high': return AppTheme.accentCoral;
      case 'medium': return Colors.orange;
      case 'low': return AppTheme.safeGreen;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.invite.childName.substring(0, 1).toUpperCase(),
                    style: AppTheme.heading2.copyWith(color: AppTheme.primaryTeal),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.invite.childName, style: AppTheme.heading2),
                    const SizedBox(height: 4),
                    Text(
                      "Parent: ${widget.invite.parentName}",
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRiskColor(widget.invite.riskLevel).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getRiskColor(widget.invite.riskLevel).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "${widget.invite.riskLevel} Risk",
                        style: AppTheme.caption.copyWith(
                          color: _getRiskColor(widget.invite.riskLevel),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "Requested\n${_formatDate(widget.invite.dateSent)}",
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Actions
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRespond(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRespond(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Accept"),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple format for now: "Oct 12"
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]} ${date.day}";
  }
}
