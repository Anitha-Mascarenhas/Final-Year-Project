import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';

class VoiceAssistantSheet extends StatefulWidget {
  final ChildProfile child;
  final VitalRecord vitals;

  const VoiceAssistantSheet({
    super.key,
    required this.child,
    required this.vitals,
  });

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _isListening = false;
  bool _isThinking = false;
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _messages.add({
      'sender': 'ai',
      'text': "Hi! I'm PoshanAi. I'm here to answer any questions about ${widget.child.name}'s growth, nutrition, or meal prep!",
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleSendMessage(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
      _inputController.clear();
      _isThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        String reply;
        if (query.contains('weight') || query.contains('tracking')) {
          reply = "${widget.child.name}'s weight (${widget.vitals.weight}kg) is tracking beautifully in the 75th percentile for his age.";
        } else if (query.contains('lunch') || query.contains('food')) {
          reply = "Soft lentil soup with mashed rice or warm ragi porridge with steamed vegetables are fantastic lunch options!";
        } else {
          reply = "${widget.child.name} is on a healthy growth path. For toddlers, offering 3 balanced main meals plus 2 gentle snacks like yogurt or sliced fruits works wonderfully!";
        }

        setState(() {
          _isThinking = false;
          _messages.add({'sender': 'ai', 'text': reply});
        });
      }
    });
  }

  void _toggleListening() {
    if (_isListening) {
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _isListening) {
        setState(() => _isListening = false);
        _handleSendMessage("Is ${widget.child.name}'s weight tracking well?");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final textMuted = AppTheme.textColorMuted(context);
    final scaffoldBg = AppTheme.scaffoldBgColor(context);
    final cardBg = AppTheme.cardBgColor(context);
    final cardBgAlt = AppTheme.cardBgAltColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: scaffoldBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          children: [
            // Title Header
            Icon(Icons.graphic_eq, color: AppTheme.primary, size: 36),
            const SizedBox(height: 6),
            Text(
              "Hi, I'm PoshanAi",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'How can I help you and your little one today?',
              style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Pulsing Mic Orb
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnim.value : 1.0,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentMint.withValues(alpha: _isListening ? 0.8 : 0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isThinking
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 54,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            Text(
              _isListening
                  ? 'Listening to your voice...'
                  : _isThinking
                      ? 'PoshanAi is thinking...'
                      : 'Tap orb to speak',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Chat Messages
            if (_messages.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isUser = msg['sender'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.primary : cardBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          msg['text']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isUser ? Colors.white : textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Suggested Prompt Chips
            Text(
              'Try asking about...',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
            ),
            const SizedBox(height: 10),

            _PromptChip(
              icon: Icons.monitor_weight_outlined,
              text: "\"Is ${widget.child.name}'s weight tracking well?\"",
              onTap: () => _handleSendMessage("Is ${widget.child.name}'s weight tracking well?"),
            ),
            const SizedBox(height: 8),
            _PromptChip(
              icon: Icons.restaurant,
              text: "\"What's a good lunch for a toddler?\"",
              onTap: () => _handleSendMessage("What's a good lunch for a toddler?"),
            ),
            const SizedBox(height: 8),
            _PromptChip(
              icon: Icons.lightbulb_outline,
              text: "\"How to handle picky eating?\"",
              onTap: () => _handleSendMessage("How to handle picky eating?"),
            ),
            const SizedBox(height: 16),

            // Text Input Field
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _inputController,
                    onFieldSubmitted: _handleSendMessage,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask PoshanAi anything...',
                      hintStyle: TextStyle(color: textSecondary),
                      filled: true,
                      fillColor: cardBgAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _handleSendMessage(_inputController.text),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PromptChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textColorPrimary(context);
    final cardBgAlt = AppTheme.cardBgAltColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardBgAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: AppTheme.accentMint, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: AppTheme.accentSage),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
