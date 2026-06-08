import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                  title: '1. Acceptance of Terms',
                  content: '''
By accessing and using DhinaDTS Attendance Management System, you agree to be bound by these Terms and Conditions. If you disagree with any part of these terms, you may not access the service.

These terms apply to employees, administrators, and authorized personnel.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '2. Service Description',
                  content: '''
DhinaDTS provides an enterprise attendance management platform including:

- Employee check-in/check-out tracking
- Attendance reports and analytics
- Leave management
- Real-time attendance monitoring
- Mobile and web access

We may modify or discontinue features with reasonable notice.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '3. User Responsibilities',
                  content: '''
As a user, you agree to:

- Provide accurate and complete information
- Maintain the security of your login credentials
- Use the service only for legitimate attendance tracking
- Report security issues immediately
- Comply with employer attendance policies
- Not manipulate or falsify attendance records
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '4. Acceptable Use Policy',
                  content: '''
You may not:

- Use the service for illegal purposes
- Attempt unauthorized access
- Interfere with service integrity
- Reverse engineer or copy the service
- Use automated scripts to manipulate attendance
- Share confidential attendance data without authorization
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '5. Data Ownership and License',
                  content: '''
- Your employer owns attendance records
- DhinaDTS owns the platform, software, and underlying technology
- DhinaDTS may process data as described in the Privacy Policy
- Anonymized data may be used for analytics and service improvement
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '6. Payment and Subscription',
                  content: '''
- Subscription fees are billed as agreed
- Payment is required in advance for each billing period
- Late payments may result in service suspension
- Price changes will be notified in advance
- Cancellation follows the agreed subscription terms
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '7. Service Level Agreement',
                  content: '''
- 99.9% uptime target for core services
- Critical issue response is prioritized
- Scheduled maintenance is notified in advance where possible
- Credits or remedies follow the active service agreement
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '8. Limitation of Liability',
                  content: '''
To the maximum extent permitted by law, DhinaDTS is not liable for indirect or consequential damages. Maximum liability is limited by the active subscription agreement.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '9. Termination',
                  content: '''
Either party may terminate according to the active agreement. Data export and access after termination are handled according to contract, policy, and legal requirements.
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '10. Governing Law',
                  content: '''
These terms are governed by applicable law and the active customer agreement.

Last updated: December 1, 2024
''',
                ),
                _sectionGap,
                _buildSection(
                  context,
                  title: '11. Contact Information',
                  content: '''
Legal Department: legal@dhinadts.com
Phone: +91 (967) 7096359
Address: 74/1 1St Street, Seetharampalayam, Tiruchengode, Tamil Nadu 637209
''',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Settings'),
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
