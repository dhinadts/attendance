import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IndustrialCard(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  context,
                  title: '1. Information We Collect',
                  content: '''
DhinaDTS collects information required to provide attendance management services.

- Personal information: name, email address, employee ID, department, position
- Attendance data: check-in/out times, location data, session duration
- Device information: IP address, device type, browser type, operating system
- Usage data: features used and service interaction
- Biometric data: facial recognition data when enabled for secure check-in
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '2. How We Use Information',
                  content: '''
We use your information for:

- Processing and tracking employee attendance
- Generating attendance reports and analytics
- Ensuring compliance with company policies
- Improving services and user experience
- Security and fraud prevention
- Communication about attendance issues or updates
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '3. Data Storage and Security',
                  content: '''
- Data is stored on secure cloud infrastructure
- Access controls restrict personal data to authorized personnel
- Operational reviews are performed to protect service integrity
- Backups and retention follow business and compliance needs
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '4. Data Retention',
                  content: '''
- Attendance records are retained for compliance and payroll requirements
- Personal information is retained while you are an active employee
- Deletion requests are handled subject to legal obligations
- Anonymized analytics may be retained for service improvement
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '5. Your Rights',
                  content: '''
Where applicable, you may request to:

- Access your personal data
- Correct inaccurate data
- Delete eligible records
- Object to processing
- Request data portability
- Withdraw consent where consent applies
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '6. Third-Party Services',
                  content: '''
We use trusted services such as Firebase, cloud storage, analytics, and email delivery to operate the platform. These services are used only for authentication, storage, notifications, analytics, and related attendance workflows.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '7. Cookies and Tracking',
                  content: '''
Essential cookies may be used for authentication, session management, preferences, and security. Disabling cookies can prevent some features from working correctly.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '8. Updates to This Policy',
                  content: '''
We may update this privacy policy periodically. Important changes may be shared by email, in-app notification, or website announcement.

Last updated: December 1, 2024
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '9. Contact Information',
                  content: '''
Email: privacy@dhinadts.com
Phone: +91 (967) 7096359
Address: 74/1 1St Street, Seetharampalayam, Tiruchengode, Tamil Nadu 637209
Data Protection Officer: dpo@dhinadts.com
''',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
              style: TextButton.styleFrom(
                foregroundColor: IndustrialColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _sectionGap = SizedBox(height: 24);

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: IndustrialColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content.trim(),
          style: TextStyle(fontSize: isMobile ? 13.5 : 14, height: 1.5),
        ),
      ],
    );
  }
}
