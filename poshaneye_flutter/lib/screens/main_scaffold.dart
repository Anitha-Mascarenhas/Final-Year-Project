import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../assistant/assistant_context.dart';
import '../assistant/assistant_tools.dart';
import '../assistant/voice_assistant_controller.dart';
=======
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_provider.dart';
import '../state/vitals_provider.dart';
>>>>>>> 9e766e47b3629f1688376fb3dd2b4d5be4238698
import '../widgets/interactive_bottom_nav.dart';
import '../widgets/voice_assistant_button.dart';
import 'home_dashboard_screen.dart';
import 'growth_tracking_screen.dart';
import 'ai_scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';

/// Central scaffold that owns the bottom navigation state.
/// All main tab screens are rendered within this widget so that
/// switching tabs never pushes a new route onto the stack.
class MainScaffold extends ConsumerStatefulWidget {
  final String childName;
  final int initialIndex;

  const MainScaffold({
    Key? key,
    this.childName = 'Aarav',
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  late int _currentIndex;
  late final VoiceAssistantController _assistantController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
<<<<<<< HEAD
    _assistantController = VoiceAssistantController(
      context: AssistantContext(
        currentScreen: _getScreenName(_currentIndex),
        childName: widget.childName,
      ),
    );
    _setupAssistantTools();
  }

  void _setupAssistantTools() {
    _assistantController.attachTools(
      AssistantTools(
        onNavigateHome: () => _onTabSelected(0),
        onNavigateScreening: _onScanPressed,
        onNavigateResults: () => _onTabSelected(1),
        onNavigateNutrition: () => _onTabSelected(3),
        onNavigateProfile: () => _onTabSelected(4),
        onGoBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            _onTabSelected(0);
          }
        },
        onRepeatCurrentPage: () {
          debugPrint('[MainScaffold] Repeat page requested for tab $_currentIndex');
        },
      ),
    );
  }

  String _getScreenName(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'results';
      case 3:
        return 'nutrition';
      case 4:
        return 'profile';
      default:
        return 'home';
=======
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVitals());
  }

  Future<void> _loadVitals() async {
    final session = ref.read(sessionProvider);
    if (session.childId != null && session.accessToken != null) {
      try {
        await ref
            .read(vitalsProvider.notifier)
            .loadForChild(session.childId!, session.accessToken!);
      } catch (_) {
        /* screens show the empty state; refresh is available on re-entry */
      }
>>>>>>> 9e766e47b3629f1688376fb3dd2b4d5be4238698
    }
  }

  void _onTabSelected(int idx) {
    if (idx == 2) return; // Scan is handled by onScanPressed
    setState(() {
      _currentIndex = idx;
    });
    _assistantController.updateContext(
      AssistantContext(
        currentScreen: _getScreenName(idx),
        childName: widget.childName,
      ),
    );
  }

  void _onScanPressed() {
    _assistantController.updateContext(
      AssistantContext(
        currentScreen: 'screening',
        childName: widget.childName,
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiScanScreen(childName: widget.childName),
      ),
    );
  }

  @override
  void dispose() {
    _assistantController.dispose();
    super.dispose();
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeDashboardScreenBody(
          childName: widget.childName,
          onNavRequested: _onTabSelected,
          onScanPressed: _onScanPressed,
        );
      case 1:
        return GrowthTrackingScreenBody(
          childName: widget.childName,
        );
      case 3:
        return NutritionPlanScreen(childName: widget.childName);
      case 4:
        return ProfileScreen(
          childName: widget.childName,
          onLogout: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (route) => false,
            );
          },
        );
      default:
        return HomeDashboardScreenBody(
          childName: widget.childName,
          onNavRequested: _onTabSelected,
          onScanPressed: _onScanPressed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool screenOwnsLayout = _currentIndex == 3 || _currentIndex == 4;

    final Widget assistantButton = Positioned(
      right: 18,
      bottom: 96,
      child: VoiceAssistantButton(controller: _assistantController),
    );

    if (screenOwnsLayout) {
      return Stack(
        children: [
          _buildCurrentScreen(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InteractiveBottomNav(
              currentIndex: _currentIndex,
              onTabSelected: _onTabSelected,
              onScanPressed: _onScanPressed,
            ),
          ),
          assistantButton,
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF1E9),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildCurrentScreen(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: InteractiveBottomNav(
                currentIndex: _currentIndex,
                onTabSelected: _onTabSelected,
                onScanPressed: _onScanPressed,
              ),
            ),
            assistantButton,
          ],
        ),
      ),
    );
  }
}

