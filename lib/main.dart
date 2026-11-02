import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const PharmaGameChangerApp());
}

class PharmaGameChangerApp extends StatelessWidget {
  const PharmaGameChangerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharma Game Changer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),

      // Session-only auth: every app launch starts at Login.
      home: const LoginScreen(),
    );
  }
}