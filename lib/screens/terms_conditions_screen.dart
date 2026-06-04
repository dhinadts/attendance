import '../widgets/app_shell.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';


class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IndustrialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: '1. Acceptance of Terms',
                  content: '''
By accessing and using DhinaDTS Attendance Management System, you agree to be bound by these Terms and Conditions. If you disagree with any part of these terms, you may not access the service.

These terms apply to all users, including employees, administrators, and authorized personnel.
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '2. Service Description',
                  content: '''
DhinaDTS provides an enterprise attendance management platform including:
• Employee check-in/check-out tracking
• Attendance reports and analytics
• Leave management
• Real-time attendance monitoring
• Integration with HR systems
• Mobile and web access

We reserve the right to modify or discontinue features with reasonable notice.
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '3. User Responsibilities',
                  content: '''
As a user, you agree to:
• Provide accurate and complete information
• Maintain the security of your login credentials
• Not share your account with others
• Use the service only for legitimate attendance tracking
• Report any security issues immediately
• Comply with your employer's attendance policies
• Not attempt to manipulate or falsify attendance records
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '4. Acceptable Use Policy',
                  content: '''
You may NOT:
• Use the service for any illegal purposes
• Attempt to gain unauthorized access to systems
• Interfere with or disrupt service integrity
• Reverse engineer or copy any part of the service
• Use automated scripts to manipulate attendance
• Share confidential company attendance data
• Use the service to harass or discriminate against others
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '5. Data Ownership and License',
                  content: '''
• Your employer owns all attendance data
• DhinaDTS owns the platform, software, and underlying technology
• You grant DhinaDTS a license to process data as outlined in our Privacy Policy
• We may use anonymized data for analytics and service improvement
• Intellectual property rights remain with DhinaDTS
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '6. Payment and Subscription',
                  content: '''
• Subscription fees are billed monthly or annually as agreed
• Payment is required in advance for each billing period
• Late payments may result in service suspension
• Refunds are provided on a case-by-case basis
• Price changes will be notified 30 days in advance
• Cancellation requires 30 days written notice
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '7. Service Level Agreement (SLA)',
                  content: '''
• 99.9% uptime guarantee for core services
• Response times: Critical issues within 1 hour
• Support hours: 24/7 for critical issues
• Scheduled maintenance notified 48 hours in advance
• Credits provided for SLA violations
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '8. Limitation of Liability',
                  content: '''
To the maximum extent permitted by law:
• DhinaDTS is not liable for indirect or consequential damages
• Maximum liability is limited to fees paid in the last 3 months
• We are not responsible for data loss due to user actions
• We don't guarantee uninterrupted or error-free service
• Force majeure events excuse performance obligations
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '9. Termination',
                  content: '''
Either party may terminate this agreement:
• By user: 30 days written notice
• By DhinaDTS: For violation of terms with 7 days notice
• Immediate termination for illegal activities or security breaches
• Data export available for 30 days after termination
• Accrued obligations survive termination
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '10. Governing Law',
                  content: '''
These terms are governed by the laws of the State of California, without regard to conflict of law principles. Any disputes shall be resolved in the courts of Santa Clara County, California.

Last updated: December 1, 2024
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '11. Contact Information',
                  content: '''
For questions about these terms:
• Legal Department: legal@dhinadts.com
• Phone: +91 (967) 7096359
• Address: 74/1 1St Street, Seetharampalayam, Tiruchengode, Tamil Nadu 637209
''',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: IndustrialColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}