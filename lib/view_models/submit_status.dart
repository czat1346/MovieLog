/// 쓰기(POST/PATCH/DELETE) 요청의 진행 상태. 회원가입·평점 등록 ViewModel이 공유합니다.
enum SubmitStatus { idle, submitting, success, error }
