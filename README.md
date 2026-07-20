# AlgoLogger iOS

AlgoLogger는 iOS 앱에서 사용할 수 있는 로깅 라이브러리 모음입니다.

- 최소 지원 버전: iOS 13.0
- Swift Package Manager 지원
- CocoaPods 지원

## 모듈 구성

- AlgoLoggerCommon: 공통 타입/프로토콜
- AlgoLogger: 기본 로깅 기능
- AlgoLoggerAWS: CloudWatch, S3 업로드 등 AWS 확장
- AlgoLoggerDatadog: Datadog 로그 전송 확장

## 설치 방법

### 1) CocoaPods

Podfile 예시:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'AlgoLogger', '~> 2.1.6'
  # 필요 시
  # pod 'AlgoLoggerAWS', '~> 2.1.6'
  # pod 'AlgoLoggerDatadog', '~> 2.1.7'
end
```

설치:

```bash
pod install
```

### 2) Swift Package Manager (SPM)

Xcode에서 Add Package Dependencies로 아래 URL 추가:

- https://github.com/Algorigo/AlgoLogger_iOS.git

코드 기반 설정 예시 (Package.swift):

```swift
dependencies: [
    .package(url: "https://github.com/Algorigo/AlgoLogger_iOS.git", from: "2.1.6")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "AlgoLogger", package: "AlgoLogger_iOS"),
            // 필요 시
            // .product(name: "AlgoLoggerAWS", package: "AlgoLogger_iOS"),
            // .product(name: "AlgoLoggerDatadog", package: "AlgoLogger_iOS")
        ]
    )
]
```

## 배포(Publish) 방법

## 1) CocoaPods 배포

아래 순서대로 진행합니다.

1. 버전 업데이트
- 배포 대상 podspec 파일의 s.version 값을 올립니다.
- 의존 pod 버전도 필요한 경우 함께 올립니다.

2. Git 태그 준비

```bash
git add .
git commit -m "Release x.y.z"
git tag x.y.z
git push origin main --tags
```

주의:
- 각 podspec의 s.source 태그는 s.version과 일치해야 합니다.

3. 스펙 검증

```bash
pod lib lint AlgoLoggerCommon.podspec --allow-warnings
pod lib lint AlgoLogger.podspec --allow-warnings
pod lib lint AlgoLoggerAWS.podspec --allow-warnings
pod lib lint AlgoLoggerDatadog.podspec --allow-warnings
```

4. trunk에 배포

```bash
pod trunk push AlgoLoggerCommon.podspec --allow-warnings
pod trunk push AlgoLogger.podspec --allow-warnings
pod trunk push AlgoLoggerAWS.podspec --allow-warnings
pod trunk push AlgoLoggerDatadog.podspec --allow-warnings
```

권장 순서:
- AlgoLoggerCommon -> AlgoLogger -> AlgoLoggerAWS/AlgoLoggerDatadog

## 2) SPM 배포

SPM은 별도 중앙 저장소에 업로드하는 방식이 아니라, Git 태그 릴리즈로 배포됩니다.

1. 배포 준비
- Package.swift가 최신 상태인지 확인합니다.
- public API 변경 사항을 점검합니다.

2. 버전 태그 생성/푸시

```bash
git add .
git commit -m "Release x.y.z"
git tag x.y.z
git push origin main --tags
```

3. Xcode/클라이언트에서 확인
- 클라이언트 프로젝트에서 패키지 버전을 x.y.z 이상으로 업데이트합니다.
- Resolve Package Versions를 실행해 신규 태그를 가져옵니다.

## 유지보수 팁

- 배포 전 테스트 앱(AlgoLoggerApp, AlgoLoggerDatadogApp)에서 기본 로그 동작을 확인하세요.
- 모듈 간 의존 버전(특히 AlgoLoggerCommon)을 함께 점검하세요.
- Datadog 모듈은 다른 모듈과 버전 정책이 다를 수 있으므로 별도 태그 전략을 사용할지 팀 내에서 합의해 두는 것을 권장합니다.
