import 'package:flutter/material.dart';
import '../assistant/assistant_state.dart';
import '../assistant/voice_assistant_controller.dart';


/// Floating AI Voice Assistant Microphone Button for PoshanEye.
///
/// Designed to blend seamlessly with PoshanEye's modern dark-emerald visual theme.
class VoiceAssistantButton extends StatefulWidget {
  final VoiceAssistantController controller;

  const VoiceAssistantButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_onControllerStateChanged);
  }

  void _onControllerStateChanged() {
    final state = widget.controller.state;
    if (state == VoiceAssistantState.listening || state == VoiceAssistantState.speaking) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Color _getButtonColor(VoiceAssistantState state) {
    switch (state) {
      case VoiceAssistantState.idle:
        return const Color(0xFF2DE099); // Primary Emerald Green
      case VoiceAssistantState.connecting:
        return const Color(0xFFFFB800); // Warm Amber
      case VoiceAssistantState.listening:
        return const Color(0xFF2DE099); // Pulsing Emerald Green
      case VoiceAssistantState.processing:
        return const Color(0xFF6C5CE7); // Deep Purple Thinking State
      case VoiceAssistantState.speaking:
        return const Color(0xFF00CEC9); // Bright Cyan Sound State
      case VoiceAssistantState.error:
        return const Color(0xFFFF4757); // Soft Red Error State
    }
  }

  Widget _buildButtonIcon(VoiceAssistantState state) {
    switch (state) {
      case VoiceAssistantState.idle:
        return const Icon(Icons.mic_rounded, color: Color(0xFF0C2417), size: 26);
      case VoiceAssistantState.connecting:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C2417)),
          ),
        );
      case VoiceAssistantState.listening:
        return const Icon(Icons.mic_rounded, color: Color(0xFF0C2417), size: 28);
      case VoiceAssistantState.processing:
        return const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26);
      case VoiceAssistantState.speaking:
        return const Icon(Icons.volume_up_rounded, color: Color(0xFF0C2417), size: 26);
      case VoiceAssistantState.error:
        return const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24);
    }
  }


  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final color = _getButtonColor(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Live Assistant Floating Banner when active or error
        if (state != VoiceAssistantState.idle)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2417).withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.controller.errorMessage ?? state.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.controller.lastSpokenText.isNotEmpty &&
                    state == VoiceAssistantState.speaking) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '"${widget.controller.lastSpokenText}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Floating Voice Assistant Button
        ScaleTransition(
          scale: (state == VoiceAssistantState.listening ||
                  state == VoiceAssistantState.speaking)
              ? _scaleAnimation
              : const AlwaysStoppedAnimation(1.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.controller.toggleSession,
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.45),
                      blurRadius: state.isListening ? 16 : 10,
                      spreadRadius: state.isListening ? 4 : 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _buildButtonIcon(state),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
