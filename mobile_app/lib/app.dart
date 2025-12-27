import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/family/family_home_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 检查登录状态
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // 根据patient_id判断：有patient_id是患者端，没有patient_id且role是family是家属端
        final patientId = authProvider.patientId;
        final role = authProvider.userRole;
        
        if (patientId != null) {
          // 有patient_id，是患者端
          return const PatientHomeScreen();
        } else if (role == 'family') {
          // 没有patient_id但是family角色，是家属端
          return const FamilyHomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

