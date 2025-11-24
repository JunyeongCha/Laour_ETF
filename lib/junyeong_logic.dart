// lib/junyeong_logic.dart

/// 준영매수법에서 다루는 ETF 종목 타입 정의
enum EtfType {
  tigerPhil,   // TIGER 미국필라델피아반도체레버리지
  kodexNasdaq, // KODEX 미국나스닥 100레버리지
  tigerNasdaq, // TIGER 미국나스닥 100레버리지
  unknown,     // 알 수 없는 종목
}

/// ETF 종목 이름(String)을 Enum으로 변환하는 헬퍼 함수
EtfType getEtfType(String etfName) {
  if (etfName.contains("필라델피아")) {
    return EtfType.tigerPhil;
  } else if (etfName.contains("KODEX 미국나스닥")) {
    return EtfType.kodexNasdaq;
  } else if (etfName.contains("TIGER 미국나스닥")) {
    return EtfType.tigerNasdaq;
  } else {
    return EtfType.unknown;
  }
}

/// Enum을 사람이 읽기 쉬운 이름으로 반환 (UI 표시용)
String getEtfName(EtfType type) {
  switch (type) {
    case EtfType.tigerPhil:
      return "TIGER 필반";
    case EtfType.kodexNasdaq:
      return "KODEX 나스닥";
    case EtfType.tigerNasdaq:
      return "TIGER 나스닥";
    default:
      return "기타 종목";
  }
}