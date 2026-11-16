import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/email_preference.dart';
import 'view_models/auth_view_model.dart';
import 'widgets/movielog_button.dart';

/// 로그인 화면. 이동은 직접 하지 않습니다.
/// login()만 호출하면 상태가 signedIn으로 바뀌고 Router(redirect)가 /home으로 보냅니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailPreference = EmailPreference();
  late final AuthViewModel _auth;
  bool _saveEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _auth.addListener(_showSessionExpired);
    // 이미 만료된 상태로 화면이 처음 열리는 경우도 처리합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final saved = await _emailPreference.read();
      if (!mounted || saved == null || saved.isEmpty) return;
      setState(() {
        _email.text = saved;
        _saveEmail = true;
      });
    } catch (_) {
      // 저장된 이메일을 못 읽어도 로그인에는 영향이 없습니다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired(); // 먼저 꺼서 같은 Snackbar가 반복되지 않게 합니다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')),
      );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final saveEmail = _saveEmail;
    await _auth.login(email, _password.text);
    // 이메일만 저장합니다. 비밀번호·토큰은 저장하지 않습니다. (성공했을 때만 갱신)
    if (_auth.status == AuthStatus.signedIn) {
      try {
        if (saveEmail) {
          await _emailPreference.save(email);
        } else {
          await _emailPreference.clear();
        }
      } catch (_) {
        // 편의 기능 실패는 로그인 결과에 영향을 주지 않습니다.
      }
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 48),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 84,
                  height: 84,
                ),
                const SizedBox(height: 24),
                const Text('MovieLog에 로그인'),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? '이메일을 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _password,
                  enabled: enabled,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  validator: (value) => (value?.isEmpty ?? true)
                      ? '비밀번호를 입력해 주세요.'
                      : null,
                  onFieldSubmitted: (_) {
                    if (enabled) _submit();
                  },
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _saveEmail,
                      onChanged: enabled
                          ? (value) =>
                                setState(() => _saveEmail = value ?? false)
                          : null,
                    ),
                    const Text('이메일 저장'),
                  ],
                ),
                // 로그인 실패(AUTH401_1 등)는 Form 오류 문구로 보여줍니다. 만료 Snackbar와 별개입니다.
                if (auth.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      auth.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: enabled ? () => context.push('/register') : null,
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
