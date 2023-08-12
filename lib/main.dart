import 'package:flutter/material.dart';
import 'package:mynotes/services/auth/auth_service.dart';

import 'constants/routes.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/notes_view.dart';
import 'views/verify_email_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      home: const HomePage(),
      routes: {
        loginRoute: (context) => const LoginView(),
        registerRoute: (context) => const RegisterView(),
        notesRoute: (context) => const NotesView(),
        verifyEmailRoute: (context) => const VerifyEmailView(),
      },
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService.firebase().initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final user = AuthService.firebase().currentUser;
          if (user != null) {
            if (user.isEmailVerified) {
              return const NotesView();
            }

            return const VerifyEmailView();
          }

          return const LoginView();
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
