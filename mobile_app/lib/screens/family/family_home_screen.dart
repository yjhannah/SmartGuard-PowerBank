import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bear_logo.dart';
import 'health_report_card.dart';
import 'activity_chart.dart';
import 'emotion_gauge.dart';
import 'alerts_screen.dart';
import 'call_fab.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  String? _patientId;
  String? _patientName;

  // 配色方案
  static const Color _backgroundColor = Color(0xFFF5F7FA);
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);

  @override
  void initState() {
    super.initState();
    _loadPatientId();
  }

  void _loadPatientId() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // 从AuthProvider获取关联的患者ID
    setState(() {
      _patientId = authProvider.patientId;
      _patientName = authProvider.username;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            _buildTopBar(),
            
            // 主内容
            Expanded(
              child: _patientId == null
                  ? _buildNoPatientView()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HealthReportCard(patientId: _patientId!),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ActivityChart(patientId: _patientId!),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: EmotionGauge(patientId: _patientId!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          AlertsScreen(patientId: _patientId!),
                          const SizedBox(height: 80), // 为FAB留出空间
                        ],
                      ),
                    ),
            ),
            
            // 底部Logo
            _buildBottomLogo(),
          ],
        ),
      ),
      floatingActionButton: _patientId != null ? CallFAB(patientId: _patientId) : null,
    );
  }

  /// 构建顶部栏
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：标题
          const Text(
            '家属端',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          
          // 右侧：退出按钮
          GestureDetector(
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_outlined,
                color: _hintColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 无关联患者时显示
  Widget _buildNoPatientView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BearLogo(size: 80),
          const SizedBox(height: 24),
          Text(
            '暂未关联患者',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请联系管理员进行关联',
            style: TextStyle(
              fontSize: 14,
              color: _hintColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部Logo
  Widget _buildBottomLogo() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        children: [
          const BearLogo(size: 40),
          const SizedBox(height: 4),
          Text(
            'SmartGuard',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _hintColor.withOpacity(0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
