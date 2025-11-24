// lib/junyeong_logic.dart

import 'dart:math'; // min, max 사용을 위해 추가
import 'package:laour_etf/junyeong_constants.dart';

/// 준영매수법에서 다루는 ETF 종목 타입 정의
enum EtfType {
  tigerPhil,   // TIGER 미국필라델피아반도체레버리지
  kodexNasdaq, // KODEX 미국나스닥 100레버리지
  tigerNasdaq, // TIGER 미국나스닥 100레버리지 (합성 아님)
  tigerNasdaqSynth, // TIGER 미국나스닥 100레버리지(합성) - [신규]
  aceTech,     // ACE 미국빅테크TOP7 Plus레버리지
  unknown,     // 알 수 없는 종목
}

/// ETF 종목 이름(String)을 Enum으로 변환하는 헬퍼 함수
EtfType getEtfType(String etfName) {
  if (etfName.contains("필라델피아")) {
    return EtfType.tigerPhil;
  } else if (etfName.contains("KODEX 미국나스닥")) {
    return EtfType.kodexNasdaq;
  } else if (etfName.contains("TIGER 미국나스닥") && etfName.contains("합성")) {
    return EtfType.tigerNasdaqSynth; // 합성
  } else if (etfName.contains("TIGER 미국나스닥")) {
    return EtfType.tigerNasdaq; // 일반
  } else if (etfName.contains("ACE")) {
    return EtfType.aceTech;
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
    case EtfType.tigerNasdaqSynth:
      return "TIGER 나스닥(합성)";
    case EtfType.aceTech:
      return "ACE 빅테크";
    default:
      return "기타 종목";
  }
}

// ------------------------------------------------------------------------
// 핵심 알고리즘 1: 통계 처리 결과 클래스 (Min/Avg/Max)
// ------------------------------------------------------------------------
class KStats {
  final double min;
  final double max;
  final double avg;

  KStats({required this.min, required this.max, required this.avg});

  // 빈 데이터일 때 반환할 기본값 (에러 방지용)
  factory KStats.empty() {
    return KStats(min: 0.0, max: 0.0, avg: 0.0);
  }
}

// ------------------------------------------------------------------------
// 핵심 알고리즘 2: IQR 기반 통계 산출 함수
// ------------------------------------------------------------------------
KStats getStats(List<double> rawData) {
  if (rawData.isEmpty) return KStats.empty();

  // 1. 오름차순 정렬 (원본 보존을 위해 복사본 사용)
  List<double> sortedData = List.from(rawData)..sort();

  // 데이터가 너무 적으면(4개 미만) IQR 계산이 부정확하므로 그냥 전체 통계 반환
  if (sortedData.length < 4) {
    double sum = sortedData.reduce((a, b) => a + b);
    return KStats(
      min: sortedData.first,
      max: sortedData.last,
      avg: sum / sortedData.length,
    );
  }

  // 2. Q1(25%), Q3(75%) 계산
  int n = sortedData.length;
  int q1Index = (n * 0.25).floor();
  int q3Index = (n * 0.75).floor();
  
  double q1 = sortedData[q1Index];
  double q3 = sortedData[q3Index];

  // 3. IQR 및 정상 범위(Fence) 계산
  double iqr = q3 - q1;
  double lowerBound = q1 - 1.5 * iqr;
  double upperBound = q3 + 1.5 * iqr;

  // 4. 이상치 제거 (Filtering)
  List<double> filteredData = sortedData.where((val) {
    return val >= lowerBound && val <= upperBound;
  }).toList();

  if (filteredData.isEmpty) return KStats.empty();

  // 5. 최종 통계 산출
  double minVal = filteredData.first; // 이미 정렬되어 있음
  double maxVal = filteredData.last;
  double sumVal = filteredData.reduce((a, b) => a + b);
  double avgVal = sumVal / filteredData.length;

  return KStats(min: minVal, max: maxVal, avg: avgVal);
}

// ------------------------------------------------------------------------
// 핵심 알고리즘 3: m값 (장외 가중치) 계산 로직
// ------------------------------------------------------------------------
double getM(EtfType type, double usClose, double afterMarket) {
  switch (type) {
    case EtfType.tigerPhil:
      // 로직: 부호가 다르면 2.8, 같으면 0.83
      if ((usClose * afterMarket) < 0) {
        return 2.8;
      } else {
        return 0.83;
      }
    
    case EtfType.kodexNasdaq:
      // 로직: 무조건 0.99
      return 0.99;

    case EtfType.tigerNasdaq:
    case EtfType.tigerNasdaqSynth: // 합성도 일단 TIGER 로직을 따름 (데이터 확인 필요 시 수정)
      // 로직: 무조건 1.01
      return 1.01;

    default:
      return 1.0; // 기본값
  }
}

// ------------------------------------------------------------------------
// 핵심 알고리즘 4: X' (미국 반영 총량) 계산 로직
// ------------------------------------------------------------------------
double getXPrime(double usClose, double afterMarket, double m) {
  // 공식: 종가 + (m * 장외)
  return usClose + (m * afterMarket);
}

// ------------------------------------------------------------------------
// 핵심 알고리즘 5: 종목별 리스트 가져오기
// ------------------------------------------------------------------------
Map<String, List<double>> getCycleLists(EtfType type) {
  switch (type) {
    case EtfType.tigerPhil:
      return {
        'kf': kf_list_phil,
        'k': k_list_phil,
        'kr': kr_list_phil,
      };
    case EtfType.kodexNasdaq:
      return {
        'kf': kf_list_kodex,
        'k': k_list_kodex,
        'kr': kr_list_kodex,
      };
    case EtfType.tigerNasdaq:
    case EtfType.tigerNasdaqSynth:
       // [주의] 현재 TIGER 나스닥(합성) 데이터는 일반 TIGER 데이터와 공유하거나
       // 추후 별도 데이터 수집 필요. 일단 공유 처리.
      return {
        'kf': kf_list_tiger,
        'k': k_list_tiger,
        'kr': kr_list_tiger,
      };
    default:
      return {
        'kf': [], 'k': [], 'kr': []
      };
  }
}