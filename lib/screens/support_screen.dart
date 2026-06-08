import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'dhinadts@gmail.com',
      queryParameters: {
        'subject': _subjectController.text.isNotEmpty
            ? _subjectController.text
            : 'Support Request - DhinaDTS',
        'body': _messageController.text,
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnackBar('Could not launch email app');
    }
  }

  Future<void> _launchPhone() async {
    final phoneUri = Uri(scheme: 'tel', path: '+91 96770 96359');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showSnackBar('Could not launch phone dialer');
    }
  }

  Future<void> _launchWebsite() async {
    final websiteUri = Uri.parse('https://dhinadts.github.io');
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open website');
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar('Please fill in both subject and message');
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSnackBar(
      'Ticket submitted successfully! We\'ll respond within 24 hours',
    );
    _subjectController.clear();
    _messageController.clear();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Support',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 900 ? 2 : 4;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth < 520 ? 0.95 : 1.15,
                children: [
                  _buildQuickSupportCard(
                    title: 'Email Support',
                    description: 'Response within 24 hours',
                    icon: Icons.email,
                    color: Colors.blue,
                    onTap: _launchEmail,
                  ),
                  _buildQuickSupportCard(
                    title: 'Phone Support',
                    description: 'Emergency support',
                    icon: Icons.phone,
                    color: Colors.green,
                    onTap: _launchPhone,
                  ),
                  _buildQuickSupportCard(
                    title: 'Knowledge Base',
                    description: 'FAQs and documents',
                    icon: Icons.menu_book,
                    color: Colors.orange,
                    onTap: _launchWebsite,
                  ),
                  _buildQuickSupportCard(
                    title: 'Live Chat',
                    description: 'Coming soon',
                    icon: Icons.chat,
                    color: Colors.purple,
                    onTap: () => _showSnackBar('Live chat coming soon!'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          IndustrialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: IndustrialColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Submit a Support Ticket',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: IndustrialColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief description of your issue',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText:
                        'Please provide detailed information about your issue...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: _isSubmitting ? 'SUBMITTING...' : 'SUBMIT TICKET',
                  icon: Icons.send,
                  onPressed: _isSubmitting ? null : _submitTicket,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Frequently Asked Questions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            question: 'How do I reset my password?',
            answer:
                'Go to the login screen and click "Forgot Password". You will receive an email with reset instructions. If you do not see it, check your spam folder.',
          ),
          _buildFAQItem(
            question: 'Why can\'t I check in?',
            answer:
                'Common reasons: you are outside the geofence, it is outside working hours, or you are already checked in. Contact your administrator if the issue persists.',
          ),
          _buildFAQItem(
            question: 'How do I view my attendance history?',
            answer:
                'Go to Attendance Details or Attendance Log to review daily attendance records and status.',
          ),
          _buildFAQItem(
            question: 'What should I do if I forget to check in/out?',
            answer:
                'Contact your administrator to request a correction. They can manually adjust your attendance record with proper approval.',
          ),
          _buildFAQItem(
            question: 'Is my data secure?',
            answer:
                'Yes, we use encrypted cloud services, access controls, and regular operational reviews. See our Privacy Policy for details.',
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IndustrialColors.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Support Hours',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Monday - Friday: 9:00 AM - 6:00 PM (IST)'),
                const Text('Saturday: 10:00 AM - 4:00 PM (IST)'),
                const Text('Sunday: Emergency support only'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Emergency Support: +91 (967) 7096359',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: IndustrialColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSupportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [Text(answer, style: const TextStyle(height: 1.5))],
      ),
    );
  }
}
