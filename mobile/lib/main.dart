import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';
import 'package:lellama_mobile/ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LellamaMarineApp());
}

/// Lellama Marine Safety & Potential Fishing Zone Platform.
class LellamaMarineApp extends StatelessWidget {
  final MarineProvider? provider;

  const LellamaMarineApp({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => provider ?? MarineProvider(),
      child: MaterialApp(
        title: MarineConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          primaryColor: MarineColors.oceanNavy,
          colorScheme: ColorScheme.fromSeed(
            seedColor: MarineColors.oceanNavy,
            primary: MarineColors.oceanNavy,
            secondary: MarineColors.safetyYellow,
          ),
          fontFamily: 'Roboto',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
