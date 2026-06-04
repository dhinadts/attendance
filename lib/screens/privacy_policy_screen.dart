import '../widgets/app_shell.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';
import 'package:attendance/utils/responsive.dart';


class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
 double _mobileCardWidth(BuildContext context) {
    final availableWidth = Responsive.width(context) - 44;
    if (availableWidth < 340) return availableWidth;
    return (availableWidth - 20) / 3;
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? 143.0 : _mobileCardWidth(context);
        final pagePadding = isWide
            ? const EdgeInsets.fromLTRB(28, 24, 28, 32)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
            
      
    
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
                  title: '1. Information We Collect',
                  content: '''
DhinaDTS collects the following information to provide and improve our attendance management services:

• Personal Information: Name, email address, employee ID, department, position
• Attendance Data: Check-in/out times, location data, session duration
• Device Information: IP address, device type, browser type, operating system
• Usage Data: How you interact with our platform, features used, time spent
• Biometric Data: (if enabled) Fingerprint or facial recognition for secure check-in
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '2. How We Use Your Information',
                  content: '''
We use your information for:
• Processing and tracking employee attendance
• Generating attendance reports and analytics
• Ensuring compliance with labor laws and company policies
• Improving our services and user experience
• Security and fraud prevention
• Communication regarding attendance issues or updates
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '3. Data Storage and Security',
                  content: '''
• Your data is stored on secure cloud servers with 256-bit encryption
• We implement industry-standard security measures including firewalls, encryption, and access controls
• Regular security audits and penetration testing
• Data backups are performed daily with 30-day retention
• Access to personal data is restricted to authorized personnel only
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '4. Data Retention',
                  content: '''
• Attendance records are retained for 7 years (compliance with labor laws)
• Personal information is retained while you're an active employee
• You may request data deletion within 30 days of employment termination
• Anonymized analytics data may be retained indefinitely
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '5. Your Rights',
                  content: '''
Under applicable data protection laws, you have the right to:
• Access your personal data
• Correct inaccurate data
• Request deletion of your data (subject to legal obligations)
• Object to data processing
• Data portability
• Withdraw consent at any time
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '6. Third-Party Services',
                  content: '''
We use trusted third-party services:
• Firebase (Google) - Authentication and database
• Cloud Storage - Secure file storage
• Analytics - Anonymous usage tracking
• Email Service - System notifications

These services comply with GDPR and other privacy regulations.
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '7. Cookies and Tracking',
                  content: '''
We use essential cookies for:
• Authentication and session management
• Remembering user preferences
• Security features

You can disable cookies in your browser, but some features may not function properly.
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '8. Updates to This Policy',
                  content: '''
We may update this privacy policy periodically. Significant changes will be notified via:
• Email notification
• In-app notification
• Website announcement

Last updated: December 1, 2024
''',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: '9. Contact Information',
                  content: '''
For privacy-related inquiries:
• Email: privacy@dhinadts.com
• Phone: +91 (967) 7096359
• Address: 74/1 1St Street, Seetharampalayam, Tiruchengode, Tamil Nadu 637209
• Data Protection Officer: dpo@dhinadts.com
''',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
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