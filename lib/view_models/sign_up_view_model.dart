import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/validators/member_validators.dart';
import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);
  final SignUpService _service;

  bool _disposed = false;

  // ---------- 제출(POST /v6/members) ----------
  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId; // 가입 성공 응답(result)에서 읽은 실제 ID입니다.
  String? passwordErrorText; // 400 비밀번호 형식 위반 → 비밀번호 입력칸에 표시
  String? snackbarMessage; // 그 외 400 · 409 → 화면 단위 오류(Snackbar)

  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null; // 서버가 거부한 값을 고치기 시작하면 서버 오류를 지웁니다.
    if (!_disposed) notifyListeners();
  }

  /// 닉네임·이메일이 바뀌면 이전 제출 오류(Snackbar 대상)도 함께 무효화합니다.
  void _clearSubmitError() {
    snackbarMessage = null;
    if (submitStatus == SubmitStatus.error) submitStatus = SubmitStatus.idle;
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return; // 연속 탭 차단
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      // result/memberId가 없으면 가입 완료로 표시하지 않고 계약 오류로 처리합니다.
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      final status = error.response?.statusCode;
      if (status == 400 && message.contains('비밀번호')) {
        passwordErrorText = message; // 필드 단위 오류
      } else {
        snackbarMessage = message; // 화면 단위 오류 (그 외 400, 409 등)
        if (status == 409) _markFinalDuplicate(request, message);
      }
    } on StateError {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    } catch (_) {
      // 파싱 실패 등 예상하지 못한 오류에도 제출 중 상태가 남지 않게 합니다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    }
    notifyListeners();
  }

  /// 중복 확인을 통과했어도 그 사이에 다른 사용자가 먼저 가입할 수 있으므로,
  /// POST의 409를 최종 중복 결과로 보고 해당 입력칸의 확인 상태를 되돌립니다.
  /// (서버는 이메일을 먼저 검사하므로 메시지에 '이메일'이 있으면 이메일만 표시합니다.)
  void _markFinalDuplicate(CreateMemberRequest request, String message) {
    if (message.contains('이메일')) {
      final email = request.email.trim();
      _duplicatedEmail = email;
      if (_currentEmail == email) {
        emailCheckStatus = CheckStatus.duplicated;
        emailErrorText = '이미 사용 중인 이메일입니다.';
      }
    } else if (message.contains('닉네임')) {
      final nickname = request.nickname.trim();
      _duplicatedNickname = nickname;
      if (_currentNickname == nickname) {
        nicknameCheckStatus = CheckStatus.duplicated;
        nicknameErrorText = '이미 사용 중인 닉네임입니다.';
      }
    }
  }

  // ---------- 닉네임 ----------
  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;
  String? _duplicatedNickname;
  String _currentNickname = '';
  int _nicknameRequestVersion = 0;

  bool get canCheckNickname =>
      validateNicknameFormat(_currentNickname) == null &&
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    _currentNickname = trimmed;
    _nicknameRequestVersion++; // 이전 요청의 응답을 무효화합니다.
    _clearSubmitError();
    if (_duplicatedNickname != null && trimmed == _duplicatedNickname) {
      nicknameCheckStatus = CheckStatus.duplicated;
      nicknameErrorText = '이미 사용 중인 닉네임입니다.';
    } else {
      nicknameCheckStatus = CheckStatus.idle;
      nicknameErrorText = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> checkNickname(String value) async {
    final requested = value.trim();
    if (requested.isEmpty ||
        requested != _currentNickname ||
        !canCheckNickname) {
      return;
    }

    final version = ++_nicknameRequestVersion;
    nicknameCheckStatus = CheckStatus.checking;
    nicknameErrorText = null;
    notifyListeners();

    try {
      final available = await _service.checkNickname(requested);
      if (_disposed ||
          version != _nicknameRequestVersion ||
          _currentNickname != requested) {
        return;
      }
      nicknameCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      nicknameErrorText = available ? null : '이미 사용 중인 닉네임입니다.';
      if (!available) _duplicatedNickname = requested;
    } on DioException {
      if (_disposed ||
          version != _nicknameRequestVersion ||
          _currentNickname != requested) {
        return;
      }
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    if (!_disposed && version == _nicknameRequestVersion) notifyListeners();
  }

  // ---------- 이메일 ----------
  CheckStatus emailCheckStatus = CheckStatus.idle;
  String? emailErrorText;
  String? _duplicatedEmail;
  String _currentEmail = '';
  int _emailRequestVersion = 0;

  bool get canCheckEmail =>
      _currentEmail.contains('@') &&
      _currentEmail.contains('.') &&
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;

  void onEmailChanged(String value) {
    final trimmed = value.trim();
    _currentEmail = trimmed;
    _emailRequestVersion++;
    _clearSubmitError();
    if (_duplicatedEmail != null && trimmed == _duplicatedEmail) {
      emailCheckStatus = CheckStatus.duplicated;
      emailErrorText = '이미 사용 중인 이메일입니다.';
    } else {
      emailCheckStatus = CheckStatus.idle;
      emailErrorText = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> checkEmail(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _currentEmail || !canCheckEmail) {
      return;
    }

    final version = ++_emailRequestVersion;
    emailCheckStatus = CheckStatus.checking;
    emailErrorText = null;
    notifyListeners();

    try {
      final available = await _service.checkEmail(requested);
      if (_disposed ||
          version != _emailRequestVersion ||
          _currentEmail != requested) {
        return;
      }
      emailCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      emailErrorText = available ? null : '이미 사용 중인 이메일입니다.';
      if (!available) _duplicatedEmail = requested;
    } on DioException {
      if (_disposed ||
          version != _emailRequestVersion ||
          _currentEmail != requested) {
        return;
      }
      emailCheckStatus = CheckStatus.error;
      emailErrorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    if (!_disposed && version == _emailRequestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nicknameRequestVersion++;
    _emailRequestVersion++;
    super.dispose();
  }
}
