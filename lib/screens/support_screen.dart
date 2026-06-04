import '../widgets/app_shell.dart';
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
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'dhinadts@gmail.com',
      queryParameters: {
        'subject': _subjectController.text.isNotEmpty 
            ? _subjectController.text 
            : 'Support Request - DhinaDTS',
        'body': _messageController.text.isNotEmpty 
            ? _messageController.text 
            : '',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnackBar('Could not launch email app');
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+91 96770 96359');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showSnackBar('Could not launch phone dialer');
    }
  }

  Future<void> _launchWebsite() async {
    final Uri websiteUri = Uri.parse('https://dhinadts.github.io');
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
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() => _isSubmitting = false);
    _showSnackBar('Ticket submitted successfully! We\'ll respond within 24 hours');
    _subjectController.clear();
    _messageController.clear();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Support Options
          Text(
            'Quick Support',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildQuickSupportCard(
                title: 'Email Support',
                description: 'Get response within 24 hours',
                icon: Icons.email,
                color: Colors.blue,
                onTap: _launchEmail,
              ),
              _buildQuickSupportCard(
                title: 'Phone Support',
                description: '24/7 emergency support',
                icon: Icons.phone,
                color: Colors.green,
                onTap: _launchPhone,
              ),
              _buildQuickSupportCard(
                title: 'Knowledge Base',
                description: 'FAQs and documentation',
                icon: Icons.menu_book,
                color: Colors.orange,
                onTap: _launchWebsite,
              ),
              _buildQuickSupportCard(
                title: 'Live Chat',
                description: 'Chat with support agent',
                icon: Icons.chat,
                color: Colors.purple,
                onTap: () => _showSnackBar('Live chat coming soon!'),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Submit Ticket Form
          IndustrialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: IndustrialColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Submit a Support Ticket',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: IndustrialColors.primary,
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
                    hintText: 'Please provide detailed information about your issue...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: PrimaryActionButton(
                        label: _isSubmitting ? 'SUBMITTING...' : 'SUBMIT TICKET',
                        icon: Icons.send,
                        onPressed: _isSubmitting ? null : _submitTicket,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // FAQ Section
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFAQItem(
            question: 'How do I reset my password?',
            answer: 'Go to the login screen and click "Forgot Password". You\'ll receive an email with reset instructions. If you don\'t see it, check your spam folder.',
          ),
          _buildFAQItem(
            question: 'Why can\'t I check in?',
            answer: 'Common reasons: You\'re outside the geofence, it\'s outside working hours, or you\'re already checked in. Contact your administrator if the issue persists.',
          ),
          _buildFAQItem(
            question: 'How do I view my attendance history?',
            answer: 'Go to the Reports section from the bottom navigation bar. You can filter by date range and export your attendance records.',
          ),
          _buildFAQItem(
            question: 'What should I do if I forget to check in/out?',
            answer: 'Contact your administrator to request a correction. They can manually adjust your attendance record with proper approval.',
          ),
          _buildFAQItem(
            question: 'Is my data secure?',
            answer: 'Yes, we use 256-bit encryption, regular security audits, and comply with GDPR and other privacy regulations. See our Privacy Policy for details.',
          ),
          
          const SizedBox(height: 32),
          
          // Contact Info Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IndustrialColors.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Support Hours',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Monday - Friday: 9:00 AM - 6:00 PM (EST)'),
                const Text('Saturday: 10:00 AM - 4:00 PM (EST)'),
                const Text('Sunday: Emergency support only'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Emergency Support: +91 (967) 7096359',
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
    return SizedBox(
      width:MediaQuery.of(context).size.width * 0.15   ,//180,
      height: MediaQuery.of(context).size.width * 0.13,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: const TextStyle(height: 1.5),
          ),
        ),
      ],
    );
  }
}