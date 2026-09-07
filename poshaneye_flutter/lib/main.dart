import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const PoshanEyeApp());
}

class PoshanEyeApp extends StatefulWidget {
  const PoshanEyeApp({super.key});

  @override
  State<PoshanEyeApp> createState() => _PoshanEyeAppState();
}

class _PoshanEyeAppState extends State<PoshanEyeApp> {
  ThemeMode _themeMode = ThemeMode.light; // Default to LIGHT mode
  bool _isAuthenticated = false;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _themeMode == ThemeMode.dark
          ? Brightness.light
          : Brightness.dark,
    ));
  }

  void _handleLoginSuccess() {
    setState(() => _isAuthenticated = true);
  }

  void _handleLogout() {
    setState(() => _isAuthenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeMode: _themeMode,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        title: 'PoshanEye',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: _isAuthenticated
            ? MainScaffold(onLogout: _handleLogout)
            : AuthScreen(onLoginSuccess: _handleLoginSuccess),
      ),
    );
  }
}
