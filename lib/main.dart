// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase 코어
import 'firebase_options.dart'; // flutterfire configure가 생성한 파일

void main() async {
  // 1. Flutter 엔진이 준비되었는지 확인
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Firebase 초기화 (4개 플랫폼 모두 선택했어도 이 코드가 알아서 처리)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. const MyApp() 호출 (오류가 발생했던 부분)
  runApp(const MyApp());
}

// 4. MyApp 클래스 (오류 수정의 핵심)
class MyApp extends StatelessWidget {
  
  // 'const'와 '{super.key}'가 key/const 관련 오류를 해결합니다.
  const MyApp({super.key});

  // 'build' 메서드가 non_abstract_class 오류를 해결합니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laour ETF',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 임시 홈 화면 (기본 카운터 앱)
      home: const MyHomePage(title: '임시 홈 화면'),
    );
  }
}

// 5. 임시 홈 화면 (기본 카운터 앱)
// (이 부분은 나중에 [개발 단계 1]에서 로그인 화면 등으로 대체될 것입니다)
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Firebase 연결 테스트용 화면입니다:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}