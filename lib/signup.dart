import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 회원가입 화면
///
/// 화면은 의미 단위로 세 개의 Widget으로 나뉩니다.
/// - [_BackHeader]: 뒤로가기 버튼 + 중앙 타이틀
/// - [_SignupForm]: 닉네임 / 이메일 / 비밀번호 입력창
/// - [_TermsAndSubmit]: 약관 동의, 가입 버튼, 로그인 이동 링크
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool? _nicknameStatus;
  bool? _emailStatus;
  bool? _passwordStatus;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _nicknameStatus == true &&
      _emailStatus == true &&
      _passwordStatus == true &&
      _agreedToTerms;

  void _onNicknameChanged(String value) {
    setState(() {
      _nicknameStatus = value.trim().length >= 2;
    });
  }

  void _onEmailChanged(String value) {
    setState(() {
      _emailStatus = value.isNotEmpty &&
          value.contains('@') &&
          value.contains('.');
    });
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordStatus = value.length >= 8;
    });
  }

  void _onTogglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _onSignupPressed() {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    FocusScope.of(context).unfocus();
    // 유효성 검사 및 약관 동의 통과 시 실행할 로직
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BackHeader(title: '회원가입'),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              _SignupForm(
                formKey: formKey,
                nicknameController: _nicknameController,
                emailController: _emailController,
                passwordController: _passwordController,
                nicknameFocusNode: _nicknameFocusNode,
                emailFocusNode: _emailFocusNode,
                passwordFocusNode: _passwordFocusNode,
                nicknameStatus: _nicknameStatus,
                emailStatus: _emailStatus,
                passwordStatus: _passwordStatus,
                obscurePassword: _obscurePassword,
                onNicknameChanged: _onNicknameChanged,
                onEmailChanged: _onEmailChanged,
                onPasswordChanged: _onPasswordChanged,
                onTogglePasswordVisibility: _onTogglePasswordVisibility,
                onSignupPressed: _onSignupPressed,
              ),
              const SizedBox(height: 64),
              _TermsAndSubmit(
                agreedToTerms: _agreedToTerms,
                onAgreedChanged: (value) {
                  setState(() {
                    _agreedToTerms = value ?? false;
                  });
                },
                isFormValid: _isFormValid,
                onSignupPressed: _onSignupPressed,
                onLoginTap: () {
                  // TODO: 로그인 화면으로 이동
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 닉네임 / 이메일 / 비밀번호 유효성에 따라 체크(✔) 또는 에러(!) 아이콘을 보여준다.
/// status가 null이면 아직 아무것도 입력하지 않은 상태이므로 아이콘을 표시하지 않는다.
Widget? _statusIcon(bool? status) {
  if (status == null) return null;
  return Padding(
    padding: const EdgeInsets.all(12),
    child: status
        ? SvgPicture.asset(
            'assets/icons/check_circle.svg',
            width: 20,
            height: 20,
          )
        : SvgPicture.asset(
            'assets/icons/error.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              Colors.red,
              BlendMode.srcIn,
            ),
          ),
  );
}

/// 모든 입력창에 공통으로 적용할 기본 둥근 테두리.
/// 평소(에러 아닐 때)에도 항상 테두리가 보이도록 한다.
const OutlineInputBorder _defaultBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFFD9D9D9), width: 1),
);

const OutlineInputBorder _focusedBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
);

/// status가 false일 때 테두리와 배경을 빨간색으로 바꿔주는 decoration 조각.
/// 평소에는 둥근 회색 테두리, 포커스 시 보라색 테두리를 적용한다.
InputDecoration _errorStyledDecoration({
  required InputDecoration base,
  required bool? status,
}) {
  final isError = status == false;

  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.red, width: 1.5),
  );

  return base.copyWith(
    filled: isError,
    fillColor: isError ? Colors.red.shade50 : null,
    border: _defaultBorder,
    enabledBorder: isError ? errorBorder : _defaultBorder,
    focusedBorder: isError ? errorBorder : _focusedBorder,
  );
}

/// 왼쪽 뒤로가기 버튼 + 중앙 타이틀을 같은 y좌표에 배치하는 상단 바.
class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/arrow_back.svg',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                // 클릭해도 아무 동작 없음
              },
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 닉네임 / 이메일 / 비밀번호 입력창.
///
/// 키보드의 '다음' 버튼을 누르면 닉네임 → 이메일 → 비밀번호 순으로 Focus가 이동하고,
/// 비밀번호에서 '완료'를 누르면 가입 버튼과 동일한 검증 로직이 실행된다.
class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.formKey,
    required this.nicknameController,
    required this.emailController,
    required this.passwordController,
    required this.nicknameFocusNode,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.nicknameStatus,
    required this.emailStatus,
    required this.passwordStatus,
    required this.obscurePassword,
    required this.onNicknameChanged,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onTogglePasswordVisibility,
    required this.onSignupPressed,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController nicknameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final FocusNode nicknameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;

  final bool? nicknameStatus;
  final bool? emailStatus;
  final bool? passwordStatus;
  final bool obscurePassword;

  final ValueChanged<String> onNicknameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSignupPressed;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nicknameController,
            focusNode: nicknameFocusNode,
            onChanged: onNicknameChanged,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => emailFocusNode.requestFocus(),
            decoration: _errorStyledDecoration(
              base: InputDecoration(
                labelText: '닉네임',
                suffixIcon: _statusIcon(nicknameStatus),
              ),
              status: nicknameStatus,
            ),
            validator: (value) {
              if (value == null || value.length < 2) {
                return '닉네임은 2자 이상이어야 합니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            focusNode: emailFocusNode,
            onChanged: onEmailChanged,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
            decoration: _errorStyledDecoration(
              base: InputDecoration(
                labelText: '이메일',
                suffixIcon: _statusIcon(emailStatus),
              ),
              status: emailStatus,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '이메일을 입력해주세요';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return '올바른 이메일 형식이 아닙니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            onChanged: onPasswordChanged,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => onSignupPressed(),
            decoration: _errorStyledDecoration(
              base: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_statusIcon(passwordStatus) != null)
                      _statusIcon(passwordStatus)!,
                    IconButton(
                      icon: SvgPicture.asset(
                        obscurePassword
                            ? 'assets/icons/visibility_off.svg'
                            : 'assets/icons/visibility.svg',
                        width: 20,
                        height: 20,
                      ),
                      onPressed: onTogglePasswordVisibility,
                    ),
                  ],
                ),
              ),
              status: passwordStatus,
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return '비밀번호는 8자 이상이어야 합니다';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

/// 필수 약관 동의 체크박스, 가입 버튼, 로그인 이동 링크.
class _TermsAndSubmit extends StatelessWidget {
  const _TermsAndSubmit({
    required this.agreedToTerms,
    required this.onAgreedChanged,
    required this.isFormValid,
    required this.onSignupPressed,
    required this.onLoginTap,
  });

  final bool agreedToTerms;
  final ValueChanged<bool?> onAgreedChanged;
  final bool isFormValid;
  final VoidCallback onSignupPressed;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: agreedToTerms,
              onChanged: onAgreedChanged,
            ),
            const Text('필수 약관에 동의합니다'),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: isFormValid ? onSignupPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            disabledBackgroundColor: const Color(0xFFD9CBFF),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('가입하기'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('이미 계정이 있나요? '),
            GestureDetector(
              onTap: onLoginTap,
              child: const Text(
                '로그인',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}