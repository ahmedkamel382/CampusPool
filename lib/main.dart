import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load the environment variables from the .env file
  await dotenv.load(fileName: ".env");

  // Wrap the entire app in the Provider
  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: const CampusPoolApp(),
    ),
  );
}

class CampusPoolApp extends StatelessWidget {
  const CampusPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusPool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          fontFamily: 'Inter',
          scaffoldBackgroundColor: Colors.white
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const MainNavigation();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}