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

        // 根据user_type判断：'patient'是患者端，'family'是家属端
        // 注意：优先使用 userType，因为 role 可能都是 'family'（数据库约束）
        final userType = authProvider.userType;
        final role = authProvider.userRole;
        
        // 患者端：userType 明确为 'patient'
        if (userType == 'patient') {
          return const PatientHomeScreen();
        }
        
        // 家属端：userType 明确为 'family'
        // 注意：不能仅凭 role == 'family' 判断，因为患者账号的 role 也可能是 'family'
        if (userType == 'family') {
          return const FamilyHomeScreen();
        }
        
        // 如果 userType 为 null 或未知，返回登录界面
        // 这通常发生在护士、医生等角色登录时
        return const LoginScreen();
      },
    );
  }
}

