import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/validators/member_validators.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';

void main() {
  group('CommonResponse', () {
    test('회원가입 201 응답을 CommonResponse<SignUpResult>로 파싱한다', () {
      final response = CommonResponse<SignUpResult>.fromJson(
        {
          'isSuccess': true,
          'code': 'COMMON201',
          'message': '성공',
          'result': {'memberId': 7, 'email': 'a@b.com', 'nickname': '무비'},
        },
        (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
      );
      expect(response.isSuccess, isTrue);
      expect(response.result?.memberId, equals(7));
      expect(response.result?.nickname, equals('무비'));
    });

    test('result가 null이면 null로 유지한다 (평점 수정 200)', () {
      final response = CommonResponse<Object?>.fromJson(
        {'isSuccess': true, 'code': 'COMMON200', 'message': 'ok', 'result': null},
        (value) => value,
      );
      expect(response.result, isNull);
    });

    test('tryParseCommonResponse: 공통 오류 형식은 읽고, 아닌 형식은 null', () {
      final ok = tryParseCommonResponse({
        'isSuccess': false,
        'code': 'COMMON409',
        'message': '이미 사용 중인 이메일입니다.',
        'result': null,
      });
      expect(ok?.code, equals('COMMON409'));
      expect(ok?.message, equals('이미 사용 중인 이메일입니다.'));

      expect(tryParseCommonResponse('<html>502</html>'), isNull);
      expect(tryParseCommonResponse(null), isNull);
      expect(tryParseCommonResponse({'status': 500}), isNull); // 필드 누락
    });
  });

  group('요청 Model', () {
    test('CreateMemberRequest: 이메일·닉네임만 trim하고 비밀번호는 그대로', () {
      const request = CreateMemberRequest(
        email: ' a@b.com ',
        password: 'Abcdef1!',
        nickname: ' 무비 ',
      );
      final json = request.toJson();
      expect(json['email'], equals('a@b.com'));
      expect(json['nickname'], equals('무비'));
      expect(json['password'], equals('Abcdef1!'));
    });

    test('CreateRatingRequest: 빈 comment는 키를 생략하고 값은 trim한다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '  ')
            .toJson()
            .containsKey('comment'),
        isFalse,
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4).toJson(),
        equals({'movieId': 550, 'score': 4}),
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 5, comment: ' 좋아요 ')
            .toJson(),
        equals({'movieId': 550, 'score': 5, 'comment': '좋아요'}),
      );
    });

    test('validateServerScore: 1~5 정수만 통과', () {
      expect(validateServerScore(1), equals(1));
      expect(validateServerScore(5.0), equals(5));
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
      expect(() => validateServerScore(3.5), throwsArgumentError);
    });
  });

  group('응답 Model', () {
    test('RatingDto: comment는 nullable', () {
      final dto = RatingDto.fromJson({
        'ratingId': 1,
        'movieId': 550,
        'score': 4,
        'comment': null,
        'createdAt': '2026-11-09T10:00:00',
      });
      expect(dto.comment, isNull);
      expect(dto.movieId, equals(550));
    });
  });

  group('로컬 검증', () {
    test('닉네임 2~12자', () {
      expect(validateNicknameFormat('a'), isNotNull);
      expect(validateNicknameFormat('ab'), isNull);
      expect(validateNicknameFormat('a' * 12), isNull);
      expect(validateNicknameFormat('a' * 13), isNotNull);
      expect(validateNicknameFormat('  a  '), isNotNull); // trim 후 길이 기준
    });

    test('비밀번호: 8자 이상 + 소/대/숫자/특수 각각 포함', () {
      expect(validatePasswordFormat('Abcdef1!'), isNull);
      expect(validatePasswordFormat('Abc1!'), isNotNull); // 짧음
      expect(validatePasswordFormat('abcdefg1!'), isNotNull); // 대문자 없음
      expect(validatePasswordFormat('ABCDEFG1!'), isNotNull); // 소문자 없음
      expect(validatePasswordFormat('Abcdefgh!'), isNotNull); // 숫자 없음
      expect(validatePasswordFormat('Abcdefg12'), isNotNull); // 특수문자 없음
      expect(validatePasswordFormat('Abcdefg1?'), isNotNull); // ?는 허용 목록 밖
      expect(validatePasswordFormat(' Abcdef1!'), isNotNull); // 앞 공백
      expect(validatePasswordFormat(''), isNotNull);
    });
  });

  group('v7 계약', () {
    Map<String, dynamic> wrapper(Object? result) => {
      'isSuccess': true,
      'code': 'COMMON200',
      'message': 'ok',
      'result': result,
    };

    test('LoginRequest: 이메일만 trim, memberId 없는 LoginResult', () {
      expect(
        const LoginRequest(email: ' a@b.com ', password: ' pw ').toJson(),
        equals({'email': 'a@b.com', 'password': ' pw '}),
      );
      final result = LoginResult.fromJson({
        'nickname': '무비',
        'accessToken': 'jwt',
      });
      expect(result.nickname, equals('무비'));
      expect(result.accessToken, equals('jwt'));
    });

    test('MemberInfo: email·nickname·createdAt만 읽는다', () {
      final info = parseMemberInfo(wrapper({
        'email': 'a@b.com',
        'nickname': '무비',
        'createdAt': '2026-10-10T09:00:00',
      }));
      expect(info.email, equals('a@b.com'));
      expect(info.createdAt.year, equals(2026));
      expect(() => parseMemberInfo(wrapper(null)), throwsStateError);
      expect(() => parseMemberInfo('html'), throwsStateError);
    });

    test('평점 등록/수정 result는 Rating 객체, null이면 성공으로 보지 않는다', () {
      final rating = parseRatingResult(wrapper({
        'ratingId': 3,
        'movieId': 550,
        'score': 4,
        'comment': null,
        'createdAt': '2026-11-16T10:00:00',
      }));
      expect(rating.ratingId, equals(3));
      expect(rating.movieId, equals(550));
      expect(() => parseRatingResult(wrapper(null)), throwsStateError);
    });

    test('공개 평점 목록은 직접 배열', () {
      final list = parseRatingList([
        {
          'ratingId': 1,
          'movieId': 10,
          'score': 5,
          'comment': '굿',
          'createdAt': '2026-11-16T10:00:00',
        },
      ]);
      expect(list.single.comment, equals('굿'));
      expect(() => parseRatingList({'result': []}), throwsStateError);
    });

    test('등록 body에 memberId가 없다', () {
      final body = const CreateRatingRequest(movieId: 550, score: 4).toJson();
      expect(body.containsKey('memberId'), isFalse);
    });

    test('apiErrorCode / apiErrorMessage / isSessionExpiredCode', () {
      DioException error(Object? data) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 401,
          data: data,
        ),
      );
      final e = error({'code': 'AUTH401_4', 'message': '만료'});
      expect(apiErrorCode(e), equals('AUTH401_4'));
      expect(apiErrorMessage(e), equals('만료'));
      expect(apiErrorCode(error('<html/>')), isNull);
      expect(isSessionExpiredCode('AUTH401_2'), isTrue);
      expect(isSessionExpiredCode('AUTH401_3'), isTrue);
      expect(isSessionExpiredCode('AUTH401_4'), isTrue);
      expect(isSessionExpiredCode('AUTH401_1'), isFalse); // 로그인 입력 오류
      expect(isSessionExpiredCode('RATING403_1'), isFalse); // 권한 부족
      expect(isSessionExpiredCode(null), isFalse);
    });
  });
}
