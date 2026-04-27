import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';

/// About HearTech — app information, disclaimer, team, and tech stack.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('About HearTech', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Logo Section ──────────────────────────────────────────────
            const Icon(Icons.hearing, size: 80, color: HearTechColors.deepTeal),
            const SizedBox(height: 12),
            const Text('HearTech', style: TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w800,
              fontSize: 28, color: HearTechColors.deepTeal,
            )),
            const SizedBox(height: 4),
            const Text('Early Hearing, Better Futures', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 14, color: HearTechColors.textSecondary,
            )),
            const SizedBox(height: 4),
            const Text('Version 1.0.0', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 12, color: HearTechColors.textSecondary,
            )),
            const SizedBox(height: 32),

            // ── What Is HearTech ──────────────────────────────────────────
            _sectionCard(
              icon: Icons.info_outline,
              title: 'What Is HearTech',
              iconColor: HearTechColors.deepTeal,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HearTech is an early childhood hearing risk screening application '
                    'designed to help healthcare workers, parents, and teachers work '
                    'together to identify and monitor potential hearing concerns in '
                    'children aged 0 to 12 years.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The app is a screening and decision-support tool. It does not '
                    'provide medical diagnoses. All results should be discussed with '
                    'a qualified healthcare professional.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Important Disclaimer ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: HearTechColors.coralRed, size: 22),
                    SizedBox(width: 10),
                    Text('Important Disclaimer', style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 16, color: HearTechColors.coralRed,
                    )),
                  ]),
                  Divider(color: HearTechColors.coralRed.withValues(alpha: 0.3), height: 20),
                  const Text(
                    'HearTech is NOT a medical diagnostic tool. The risk assessments '
                    'provided are based on observational screening data and are intended '
                    'to guide — not replace — clinical evaluation.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Always consult a qualified audiologist, ENT specialist, or '
                    'paediatrician for a formal hearing assessment.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── How It Works ──────────────────────────────────────────────
            _sectionCard(
              icon: Icons.format_list_numbered,
              title: 'How It Works',
              iconColor: HearTechColors.deepTeal,
              child: Column(
                children: [
                  _step(1, Icons.local_hospital,
                    'A healthcare worker conducts an initial screening using '
                    'age-appropriate questionnaires. If a risk is detected, a '
                    'child profile is created.',
                  ),
                  const SizedBox(height: 14),
                  _step(2, Icons.family_restroom,
                    'The parent downloads HearTech and uses a secure handover '
                    'code to link their child\'s profile. They can then run home '
                    'screenings and speech exercises.',
                  ),
                  const SizedBox(height: 14),
                  _step(3, Icons.school,
                    'The parent can invite the child\'s teacher to observe and '
                    'contribute classroom observations, creating a complete '
                    'picture of the child\'s development.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Development Team ──────────────────────────────────────────
            _sectionCard(
              icon: Icons.people,
              title: 'Development Team',
              iconColor: HearTechColors.deepTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _teamMember('Noor Hassan', 'Frontend Developer & Testing'),
                  const SizedBox(height: 12),
                  _teamMember('Haroon Ashar', 'AI & Backend Developer'),
                  const SizedBox(height: 12),
                  _teamMember('Abdul Mateen', 'UI/UX & Documentation'),
                  const SizedBox(height: 16),
                  const Text('Supervised by:', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 12,
                    color: HearTechColors.textSecondary,
                  )),
                  const SizedBox(height: 4),
                  const Text('Mr. Ihtisham-Ul-Haq', style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                    fontSize: 14, color: HearTechColors.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  const Text(
                    'University of Central Punjab — Group F25CS070',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: HearTechColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Technical Information ─────────────────────────────────────
            _sectionCard(
              icon: Icons.code,
              title: 'Technical Information',
              iconColor: HearTechColors.deepTeal,
              child: const Column(
                children: [
                  _TechRow(label: 'Platform', value: 'Flutter (iOS & Android)'),
                  _TechRow(label: 'Backend', value: 'FastAPI on Google Cloud Run'),
                  _TechRow(label: 'Database', value: 'Firebase Firestore'),
                  _TechRow(label: 'AI Model', value: 'Custom Risk Classification'),
                  _TechRow(label: 'Speech', value: 'Whisper ASR'),
                  _TechRow(label: 'Notifications', value: 'OneSignal'),
                  _TechRow(label: 'File Storage', value: 'Cloudinary'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Data & Privacy ────────────────────────────────────────────
            _sectionCard(
              icon: Icons.shield_outlined,
              title: 'Data & Privacy',
              iconColor: HearTechColors.deepTeal,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HearTech stores only the minimum information necessary to '
                    'provide the screening service. Child data is accessible only '
                    'to the linked healthcare worker, parent, and teacher.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No data is shared with third parties. All data is stored '
                    'securely using Firebase Firestore with role-based access controls.',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        color: HearTechColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Copyright ─────────────────────────────────────────────────
            const Text('© 2025 HearTech — University of Central Punjab',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  color: HearTechColors.textSecondary),
            ),
            const SizedBox(height: 2),
            const Text('Final Year Project — Group F25CS070',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  color: HearTechColors.textSecondary),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: HearTechDecorations.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16,
              color: HearTechColors.textPrimary,
            )),
          ]),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _step(int number, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(
            color: HearTechColors.deepTeal, shape: BoxShape.circle,
          ),
          child: Center(child: Text('$number', style: const TextStyle(
            fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 14, color: HearTechColors.white,
          ))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HearTechColors.deepTeal, size: 20),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 14,
                color: HearTechColors.textPrimary, height: 1.5,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamMember(String name, String role) {
    return Row(
      children: [
        AvatarCircle(name: name, size: 40),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w700,
              fontSize: 14, color: HearTechColors.textPrimary,
            )),
            Text(role, style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 12,
              color: HearTechColors.textSecondary,
            )),
          ],
        ),
      ],
    );
  }
}

/// Technical detail row — label : value.
class _TechRow extends StatelessWidget {
  final String label;
  final String value;
  const _TechRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 13,
              color: HearTechColors.textSecondary,
            )),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w600,
              color: HearTechColors.textPrimary,
            )),
          ),
        ],
      ),
    );
  }
}
