import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/interactive_eye_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: PoshanEyeApp()));
}

class PoshanEyeApp extends StatelessWidget {
  const PoshanEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PoshanEye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return MouseRegion(
          onHover: (event) =>
              InteractiveEyeLogoState.updateMountedTargets(event.position),
          child: Listener(
            onPointerDown: (event) =>
                InteractiveEyeLogoState.updateMountedTargets(event.position),
            onPointerMove: (event) =>
                InteractiveEyeLogoState.updateMountedTargets(event.position),
            onPointerHover: (event) =>
                InteractiveEyeLogoState.updateMountedTargets(event.position),
            onPointerUp: (event) =>
                InteractiveEyeLogoState.updateMountedTargets(event.position),
            child: Container(
              color: const Color(0xFF0C2417),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      routerConfig: appRouter,
    );
  }
}
