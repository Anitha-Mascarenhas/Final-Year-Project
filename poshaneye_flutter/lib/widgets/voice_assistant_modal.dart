import 'package:flutter/material.dart';
import '../assistant/assistant_state.dart';
import '../assistant/voice_assistant_controller.dart';
import '../theme/app_colors.dart';

/// Compact PoshanEye Voice Assistant Bottom Sheet / Modal.
///
/// Features:
/// - Assistant greeting
/// - Microphone button (with listening animation)
/// - Recognized speech text display
/// - Natural assistant response display
/// - Live listening status indicator
/// - Mute/unmute voice response toggle
/// - Close button
class VoiceAssistantModal extends StatefulWidget {
  final VoiceAssistantController controller;

  const VoiceAssistantModal({
    Key? key,
    required this.controller,
  }) : super(key: key);

  /// Helper to display the compact voice assistant modal sheet.
  static Future<void> show(BuildContext context, VoiceAssistantController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceAssistantModal(controller: controller),
    );
  }

  @override
  State<VoiceAssistantModal> createState() => _VoiceAssistantModalState();
}

class _VoiceAssistantModalState extends State<VoiceAssistantModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_onStateChanged);
    _syncPulseAnimation();
  }

  void _onStateChanged() {
    _syncPulseAnimation();
    if (mounted) setState(() {});
  }

  void _syncPulseAnimation() {
    if (widget.controller.isListening) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildStatusBadge(VoiceAssistantState state) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case VoiceAssistantState.listening:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF1B5E20);
        label = 'Listening... Speak now';
        icon = Icons.mic;
        break;
      case VoiceAssistantState.processing:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Processing query...';
        icon = Icons.sync_rounded;
        break;
      case VoiceAssistantState.speaking:
        bg = const Color(0xFFE0F7FA);
        fg = const Color(0xFF006064);
        label = 'Assistant speaking...';
        icon = Icons.volume_up_rounded;
        break;
      case VoiceAssistantState.error:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = 'Attention needed';
        icon = Icons.warning_amber_rounded;
        break;
      case VoiceAssistantState.idle:
      default:
        bg = AppColors.accentSageLight;
        fg = AppColors.primaryForest;
        label = 'Ready';
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.state;
    final isListening = controller.isListening;
    final isSpeaking = controller.isSpeaking;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row: Title, Mute/Unmute, Close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentSageLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assistant_rounded,
                      color: AppColors.primaryForest,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'PoshanEye Voice Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  // Mute / Unmute Button
                  IconButton(
                    icon: Icon(
                      controller.isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: controller.isMuted ? Colors.grey : AppColors.primaryForest,
                    ),
                    tooltip: controller.isMuted ? 'Unmute voice' : 'Mute voice',
                    onPressed: controller.toggleMute,
                  ),
                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    tooltip: 'Close',
                    onPressed: () {
                      controller.stopListening();
                      controller.stopSpeaking();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Status and Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Health & Growth Companion',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _buildStatusBadge(state),
                ],
              ),

              const SizedBox(height: 14),

              // Recognized Speech Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isListening
                        ? AppColors.neonGreen.withOpacity(0.8)
                        : AppColors.cardBorder,
                    width: isListening ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'YOU SAID',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isListening) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.neonGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.recognizedText.isNotEmpty
                          ? '"${controller.recognizedText}"'
                          : (isListening
                              ? 'Listening... Speak your command or question'
                              : 'Tap the microphone below to start speaking...'),
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: controller.recognizedText.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontWeight: controller.recognizedText.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: controller.recognizedText.isNotEmpty
                            ? AppColors.textDark
                            : AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Assistant Response Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentSageLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ASSISTANT',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryForest,
                          ),
                        ),
                        if (isSpeaking)
                          const Row(
                            children: [
                              Icon(Icons.graphic_eq_rounded,
                                  size: 14, color: AppColors.primaryForest),
                              SizedBox(width: 4),
                              Text(
                                'Speaking',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryForest,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.lastResponse.isNotEmpty
                          ? controller.lastResponse
                          : (controller.errorMessage ??
                              'Hi! I can help you navigate to screens or answer questions about child malnutrition, stunting, wasting, and screening.'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: controller.errorMessage != null
                            ? const Color(0xFFC62828)
                            : AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Suggested Commands Row
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildQuickChip('Go to home'),
                    _buildQuickChip('Open growth tracking'),
                    _buildQuickChip('Open nutrition screening'),
                    _buildQuickChip('Open history'),
                    _buildQuickChip('Open profile'),
                    _buildQuickChip('What is PoshanEye?'),
                    _buildQuickChip('What is malnutrition?'),
                    _buildQuickChip('What is stunting?'),
                    _buildQuickChip('What is wasting?'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Central Microphone Button & Control
              Center(
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                      child: GestureDetector(
                        onTap: () {
                          if (isListening) {
                            controller.stopListening();
                          } else if (isSpeaking) {
                            controller.stopSpeaking();
                          } else {
                            controller.startListening();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening
                                ? const Color(0xFF2DE099)
                                : (isSpeaking
                                    ? const Color(0xFF00CEC9)
                                    : AppColors.primaryForest),
                            boxShadow: [
                              BoxShadow(
                                color: (isListening
                                        ? const Color(0xFF2DE099)
                                        : AppColors.primaryForest)
                                    .withOpacity(0.35),
                                blurRadius: isListening ? 18 : 10,
                                spreadRadius: isListening ? 4 : 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening
                                ? Icons.stop_rounded
                                : (isSpeaking
                                    ? Icons.volume_off_rounded
                                    : Icons.mic_rounded),
                            color: isListening ? const Color(0xFF0C2417) : Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isListening
                          ? 'Tap to stop listening'
                          : (isSpeaking ? 'Tap to stop speaking' : 'Tap microphone to speak'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.primaryForest,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.accentSageLight,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: () {
          widget.controller.processVoiceInput(label);
        },
      ),
    );
  }
}
