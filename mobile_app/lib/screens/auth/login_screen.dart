import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 配色方案
  static const Color _backgroundColor = Color(0xFFF5F7FA);
  static const Color _medicalBlue = Color(0xFFE3F2FD);
  static const Color _accentBlue = Color(0xFF90CAF9);
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _textColor = Color(0xFF546E7A);
  static const Color _hintColor = Color(0xFF90A4AE);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录失败，请检查用户名和密码'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppRouter()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 小熊Logo
                      _buildLogo(),
                      const SizedBox(height: 24),
                      
                      // 标题
                      const Text(
                        'SmartGuard',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 副标题
                      Text(
                        '智能健康守护',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _hintColor.withOpacity(0.8),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 56),
                      
                      // 用户名输入框
                      _buildTextField(
                        controller: _usernameController,
                        hintText: '用户名',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入用户名';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // 密码输入框
                      _buildTextField(
                        controller: _passwordController,
                        hintText: '密码',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: _hintColor,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // 登录按钮
                      _buildLoginButton(),
                      const SizedBox(height: 32),
                      
                      // 底部提示
                      Text(
                        '安全登录 · 数据加密',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hintColor.withOpacity(0.6),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建Logo
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: _medicalBlue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(80, 80),
          painter: _BearLogoPainter(),
        ),
      ),
    );
  }

  /// 构建输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 16,
          color: _textColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: _hintColor.withOpacity(0.6),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              prefixIcon,
              color: _accentBlue,
              size: 22,
            ),
          ),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: suffixIcon,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _accentBlue,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red[300]!,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red[400]!,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          errorStyle: TextStyle(
            color: Colors.red[400],
            fontSize: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }

  /// 构建登录按钮
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accentBlue,
          elevation: 0,
          shadowColor: _primaryBlue.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}

/// 小熊Logo绘制器
class _BearLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFE3F2FD)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 80;

    // 小熊头部（主体）
    final headPath = Path();
    headPath.addOval(Rect.fromCenter(
      center: Offset(center.dx, center.dy + 4 * scale),
      width: 52 * scale,
      height: 48 * scale,
    ));
    
    canvas.drawPath(headPath, fillPaint);
    canvas.drawPath(headPath, paint);

    // 左耳
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 20 * scale, center.dy - 16 * scale),
        width: 16 * scale,
        height: 16 * scale,
      ),
      fillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 20 * scale, center.dy - 16 * scale),
        width: 16 * scale,
        height: 16 * scale,
      ),
      paint,
    );

    // 右耳
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 20 * scale, center.dy - 16 * scale),
        width: 16 * scale,
        height: 16 * scale,
      ),
      fillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 20 * scale, center.dy - 16 * scale),
        width: 16 * scale,
        height: 16 * scale,
      ),
      paint,
    );

    // 眼睛
    final eyePaint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx - 10 * scale, center.dy - 2 * scale),
      4 * scale,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + 10 * scale, center.dy - 2 * scale),
      4 * scale,
      eyePaint,
    );

    // 鼻子
    final nosePath = Path();
    nosePath.moveTo(center.dx, center.dy + 6 * scale);
    nosePath.lineTo(center.dx - 5 * scale, center.dy + 12 * scale);
    nosePath.lineTo(center.dx + 5 * scale, center.dy + 12 * scale);
    nosePath.close();
    canvas.drawPath(nosePath, eyePaint);

    // 爱心
    final heartPaint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.fill;
    
    final heartPath = Path();
    final heartCenter = Offset(center.dx, center.dy + 24 * scale);
    final heartSize = 12 * scale;
    
    heartPath.moveTo(heartCenter.dx, heartCenter.dy + heartSize * 0.3);
    heartPath.cubicTo(
      heartCenter.dx - heartSize, heartCenter.dy - heartSize * 0.5,
      heartCenter.dx - heartSize, heartCenter.dy + heartSize * 0.2,
      heartCenter.dx, heartCenter.dy + heartSize,
    );
    heartPath.moveTo(heartCenter.dx, heartCenter.dy + heartSize * 0.3);
    heartPath.cubicTo(
      heartCenter.dx + heartSize, heartCenter.dy - heartSize * 0.5,
      heartCenter.dx + heartSize, heartCenter.dy + heartSize * 0.2,
      heartCenter.dx, heartCenter.dy + heartSize,
    );
    
    canvas.drawPath(heartPath, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
