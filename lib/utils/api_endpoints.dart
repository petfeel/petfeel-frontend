// lib/utils/api_endpoints.dart

class ApiEndpoints {
  /// 공통 Base URL - 에뮬레이터와 실제 기기 모두 사용 가능하도록 설정
  // static const String base = 'http://192.168.219.72:8000';
  static const String base = 'http://192.168.0.94:8000';
  /// WebSocket Base URL - HTTP 주소와 동일한 서버 사용
  // static const String webSocketBase = 'ws://192.168.219.72:8000';
  static const String webSocketBase = 'ws://192.168.0.94:8000';

  /// Auth
  static const String register = '$base/auth/register';
  static const String login  = '$base/auth/login';
  static const String signup = '$base/auth/signup';
  static const String refreshToken = '$base/auth/refresh';

  /// Pet CRUD
  static const String getPets      = '$base/pets/';
  static const String getPetById   = '$base/pets/{id}';    // 사용 시 {id}를 치환
  static const String createPet    = '$base/pets/';
  static const String updatePet    = '$base/pets/{id}';    // 사용 시 {id}를 치환
  static const String deletePet    = '$base/pets/{id}';    // 사용 시 {id}를 치환

  /// Streaming
  static const String stream         = '$base/stream';
  static const String recordStart    = '$base/record/start/{petId}';  // {petId}
  static const String recordStop     = '$base/record/stop';
  static const String recordRename   = '$base/record/stop/rename';

  /* ───────────────── Recorded Video ───────────────── */
  static const String listVideos     = '$base/record/list';
  static const String playFile       = '$base/record/file/{filename}';  // {filename}
  static const String deleteVideo    = '$base/record/{id}';             // {id}

  /* ───────────────── 음성 녹음 ───────────────── */
  static const String listVoices     = '$base/voice/list';
  static const String playVoice      = '$base/voice/play/{id}';         // GET /voice/play/{id}
  static const String deleteVoice    = '$base/voice/{id}';              // DELETE /voice/{id}
  static const String renameVoice    = '$base/voice/{id}';              // PATCH /voice/{id}

  /* ───────────────── Voice Upload ───────────────── */
  static const String uploadVoice    = '$base/voice/upload/{petName}';  // {petName}

  /// 알림 관련
  static const String notifications = '$base/notifications';
  static const String getEvents     = '$base/events';
  static const String getEventById  = '$base/events/{id}';  // 사용 시 {id}를 치환

  /// 일기 관련
  static const String diary        = '$base/diary/{pet_id}/{year}/{month}/{day}';  // 일기 가져오기/생성
  static const String weeklySummary = '$base/weekly-summary/{pet_id}';  // 주간 요약
  static const String dailySummary  = '$base/daily-summary/{pet_id}/{date}';  // 일일 요약
  static const String dailySummaryView = '$base/daily-summary-view/{pet_id}/{date}';  // 일일 요약 조회만 (생성 안함)

  /// 상담 관련
  static const String consultations = '$base/consultations';

  /// 음성 재생 API 엔드포인트
  static const String playVoiceOnServer = '$base/voice/play-on-server/{id}';

// ───────── 예시 ─────────
// 사용 예시:
// final url = Uri.parse(ApiEndpoints.getPets);
// final url = Uri.parse(ApiEndpoints.getPetById.replaceFirst('{id}', '123'));
// final url = Uri.parse(ApiEndpoints.recordStart.replaceFirst('{petId}', widget.petData['id'].toString()));
// final url = Uri.parse(ApiEndpoints.uploadVoice.replaceFirst('{petName}', Uri.encodeComponent('가나다')));
}
