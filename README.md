# 기계가공 공정 관리 시스템 — Mini MES

소규모 가상 기계가공 공장의 업무를 단계적으로 구현하는 MES 취업용 포트폴리오입니다. 제조 공정 지식과 Java 개발 능력을 함께 설명하는 것이 목표입니다. 실제 공장에 적용하는 제품이 아니며, 모든 예시는 교육용 가상 데이터입니다.

## 현재 구현 범위

- 한국어 품목 목록, 품번·품목명 검색, 페이지당 20건 조회
- 품목 등록·수정: 품번, 품목명, 도면번호, 설명, 사용 여부
- 수정 화면에서 비활성화·재활성화. 삭제 API와 삭제 버튼은 없음
- 필수값·최대 길이·품번 형식 검증, 중복 품번 오류 표시
- 소문자 품번을 대문자로 변환하고 입력값 앞뒤 공백 제거
- DB 고유 제약으로 중복을 최종 차단하고, 버전 필드로 오래된 수정 화면의 덮어쓰기 방지
- Flyway V1 테이블 생성 이력, `dev` 프로필에서만 가상 품목 3개 추가

설비, 공정, 작업지시, 생산실적, 불량, 통계, 로그인, 권한, 실적 변경 이력, CSV는 아직 구현하지 않았습니다. 화면에도 구현한 품목 관리 메뉴만 표시합니다. 로그인과 CSRF 보호를 포함하는 보안 기능은 후속 단계입니다. 기본 서버 주소는 `127.0.0.1`이며 로컬 개발용으로만 실행합니다.

## 기술 구성

| 구분 | 구성 |
| --- | --- |
| 언어 | Java 21 |
| 서버 | Spring Boot 4.1.1, Spring MVC |
| 화면 | Thymeleaf, Bootstrap 5.3.8 (프로젝트 안에 CSS 포함) |
| 데이터 | Spring Data JPA, MySQL 8.x |
| 스키마 이력 | Flyway |
| 빌드 | Maven 3.9.11, 공식 Maven Wrapper 3.3.2 |
| 검증 | JUnit, MockMvc, 테스트 전용 H2, 별도 MySQL 검증 |

Spring Boot 4.1.1은 Java 21을 지원하는 안정 버전입니다. 의존성 버전은 Spring Boot가 관리합니다. Lombok 없이 생성자와 getter를 직접 작성해 초급자가 코드를 따라갈 수 있게 했습니다.

- [Spring Boot 호환성](https://docs.spring.io/spring-boot/system-requirements.html)
- [Flyway를 통한 초기화](https://docs.spring.io/spring-boot/how-to/data-initialization.html)
- [공식 Maven Wrapper](https://maven.apache.org/wrapper/)

## 확인한 개발 환경 (2026-10-04, 한국 시간)

| 항목 | 확인 결과 |
| --- | --- |
| OS / 셸 | Windows / Windows PowerShell |
| `java` / `javac` | Zulu JDK 21.0.4, `C:\Program Files\Zulu\zulu-21` |
| 기존 `JAVA_HOME` | Eclipse Adoptium JDK 17.0.12.7을 가리킴 |
| Maven | PATH에서 찾지 못함. Wrapper로 다운로드·빌드 가능 |
| MySQL | Server / Workbench 8.0 설치 폴더 존재. 실행 파일 버전 8.0.40 |
| MySQL PATH | `mysql` 명령은 PATH에서 찾지 못함. 아래 절대 경로로 실행 가능 |
| 기존 MySQL 포트 | `127.0.0.1:3306` TCP 연결 응답 확인. 계정 로그인은 미확인 |
| Git | 2.53.0.windows.1 |
| Docker | PATH에서 찾지 못함. 이 프로젝트에 필요하지 않음 |

기존 `auction`, `chapter1`, `stickers`, `x-follow-checker` 등은 보존했습니다. 시스템 PATH, JAVA_HOME, MySQL 서비스 설정도 변경하지 않았습니다. 검증 결과와 한계는 [docs/verification.md](docs/verification.md)를 참고하세요.

## 실행 방법 — Windows PowerShell

### 1. 폴더 이동과 Java 확인

```powershell
cd C:\Users\qkqhw\vsc\mini-mes
java --version
javac --version
```

이 환경에서는 `java`가 21이고 `JAVA_HOME`이 17이므로 `scripts/maven.ps1`을 사용합니다. 이 스크립트는 PATH의 Java 경로를 확인해 **해당 프로세스에서만** JAVA_HOME을 지정하고 종료 시 복원합니다. Maven 다운로드와 의존성은 `.m2-local` 안에 저장하므로 별도 Maven 설치가 필요 없습니다. 첫 빌드에는 인터넷이 필요합니다.

```powershell
.\scripts\maven.ps1 -B -ntp test
# PATH에 Java 21이 없다면 설치된 JDK 경로를 명시
.\scripts\maven.ps1 -JdkHome 'C:\Program Files\Zulu\zulu-21' -B -ntp test
```

Java 21 JDK가 없는 다른 PC에서는 [Eclipse Temurin Java 21](https://adoptium.net/temurin/releases/?version=21) JDK를 설치하고 위 `-JdkHome`으로 지정하세요. Maven을 따로 설치할 필요는 없습니다. PowerShell 실행 정책이 스크립트를 차단하면 해당 실행에만 다음 형태를 사용할 수 있습니다. 시스템 실행 정책은 변경하지 않습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\maven.ps1 -B -ntp test
```

Java 21의 JAVA_HOME이 이미 올바른 다른 환경에서는 `./mvnw test` 또는 `.\mvnw.cmd test`를 직접 사용할 수 있습니다. `.mvn/maven.config`는 의존성 저장 위치를 프로젝트 내부로 지정합니다. Windows 이외의 환경에서는 필요한 경우 `chmod +x mvnw`로 실행 권한을 부여하세요.

### 2. MySQL 개발 DB 준비

**아래 작업은 사용자가 자신의 MySQL에 접속해 수행하는 준비 절차입니다. 기존 3306 서버에는 실행하지 않았습니다.** 기존 서버의 계정과 포트를 먼저 확인하세요. MySQL이 없는 PC에서는 [MySQL Community Server 8.x](https://dev.mysql.com/downloads/mysql/)를 설치·구성하세요. 이 PC에는 실행 파일이 있으므로 바로 재설치할 필요는 없습니다.

Workbench의 SQL 탭 또는 아래 클라이언트로 관리자 접속합니다. `-p` 뒤에 비밀번호를 적지 않고 프롬프트에서 입력하세요.

```powershell
& 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' -h 127.0.0.1 -P 3306 -u root -p
```

```sql
SELECT VERSION();
CREATE DATABASE mini_mes CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'mini_mes_app'@'127.0.0.1' IDENTIFIED BY '여기에_직접_정한_비밀번호';
GRANT SELECT, INSERT, UPDATE, CREATE, ALTER, INDEX, REFERENCES
    ON mini_mes.* TO 'mini_mes_app'@'127.0.0.1';
```

`CREATE DATABASE`나 `CREATE USER`에서 이미 존재한다는 오류가 나면 기존 용도를 확인하고 다른 이름을 사용하세요. 기존 DB를 초기화하거나 삭제하지 마세요. 테이블은 앱 최초 실행 시 Flyway가 생성합니다. DB 서버를 설치했다는 사실만으로 계정·스키마까지 준비된 것은 아닙니다.

### 3. 현재 터미널에 접속 정보 지정

```powershell
$env:DB_USERNAME = 'mini_mes_app'
$dbSecret = Read-Host 'MySQL 앱 계정 비밀번호' -AsSecureString
$env:DB_PASSWORD = (New-Object System.Net.NetworkCredential('', $dbSecret)).Password
# 기본 주소: jdbc:mysql://127.0.0.1:3306/mini_mes?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8
# 다른 포트/DB를 사용한다면 DB_URL을 지정
# $env:DB_URL = 'jdbc:mysql://127.0.0.1:3307/mini_mes?connectionTimeZone=Asia/Seoul&characterEncoding=UTF-8'
```

비밀번호를 파일, Git, 실행 명령의 인자로 저장하지 않습니다. 환경변수는 현재 터미널에서 실행한 앱에 전달됩니다. 이 프로젝트는 `.env`를 자동으로 읽지 않습니다.

MySQL 접속 오류별 확인 지점:

- `Communications link failure`: 서버 실행 여부와 DB_URL의 포트 확인
- `Unknown database`: 위 CREATE DATABASE 준비 여부 확인
- `Access denied`: 앱 계정·비밀번호·접속 호스트 확인
- `Public Key Retrieval is not allowed`: 로컬 서버의 TLS 설정을 먼저 확인. 교육용 로컬 루프백 연결에서만 DB_URL 끝에 `&sslMode=DISABLED&allowPublicKeyRetrieval=true`를 지정할 수 있음. 외부 서버용 설정으로 사용하지 않음
- Java 버전 오류: `maven.ps1 -JdkHome`으로 Java 21 지정

### 4. 개발 모드 실행

```powershell
.\scripts\maven.ps1 -B -ntp spring-boot:run '-Dspring-boot.run.profiles=dev'
```

브라우저에서 **http://127.0.0.1:8080/items** 접속. 중지는 실행 터미널에서 `Ctrl+C`입니다. 8080 포트가 사용 중이면 실행 전에 `$env:SERVER_PORT = '8081'`로 현재 터미널의 포트를 바꾸세요.

`dev`는 `DEMO-SHAFT-001`, `DEMO-BRACKET-001`, `DEMO-BUSH-001`을 없을 때만 등록합니다. 이미 있는 품목의 수정 내용과 비활성 상태는 바꾸지 않습니다. 설명에 있는 공정 순서는 향후 계획을 적은 메모이며 실제 공정 데이터는 아닙니다.

예시 데이터를 추가하지 않는 실행:

```powershell
.\scripts\maven.ps1 -B -ntp spring-boot:run
```

기존 터미널에 `SPRING_PROFILES_ACTIVE=dev`가 설정되어 있으면 그 설정도 적용됩니다. 예시 데이터가 필요한 개발 DB에서만 `dev`를 사용하세요.

JAR 생성 및 실행:

```powershell
.\scripts\maven.ps1 -B -ntp verify
& 'C:\Program Files\Zulu\zulu-21\bin\java.exe' -jar target/mini-mes-0.0.1-SNAPSHOT.jar --spring.profiles.active=dev
```

## 검증 실행

```powershell
# 외부 DB 없이 H2 메모리 DB로 화면→서비스→DB 흐름 검증
.\scripts\maven.ps1 -B -ntp verify

# 설치된 MySQL 바이너리로 완전히 별도 서버를 만들어 실제 MySQL 검증
.\scripts\verify-mysql.ps1
# 다른 설치 경로나 충돌하는 포트가 있으면 지정
# .\scripts\verify-mysql.ps1 -MySqlHome 'D:\mysql' -JdkHome 'D:\jdk-21' -DbPort 13307 -WebPort 18081
```

`verify-mysql.ps1`은 새 `.tools/mysql-verify-<GUID>` 데이터 폴더, `127.0.0.1:13306`, 테스트 전용 `mini_mes_verify` DB를 사용합니다. 기존 서버 설정을 읽지 않으며 서비스를 설치하지 않습니다. 초기화 직후 임의의 root·앱 비밀번호를 메모리에서 지정합니다. 기존 개발 DB를 테스트 대상으로 쓰지 않습니다. 검증 후 자신이 실행한 앱·DB 프로세스만 종료하고, 검증 파일은 삭제하지 않고 `.tools`에 보존합니다. 비밀번호는 파일로 저장하지 않아 이 데이터 폴더는 재사용 개발 DB가 아닙니다.

일반 검증에서는 MySQL 테스트 12개가 **건너뛰기**로 표시됩니다. 이 스크립트는 그 12개도 실행하고, 실제 HTTP 등록·중복·수정·비활성화 및 앱 재시작 후 데이터 보존을 확인합니다. H2는 테스트 전용 의존성으로 실행용 JAR에는 포함되지 않습니다.

## 구조와 학습 문서

```text
src/main/java/com/example/minimes/
  MiniMesApplication.java
  item/       Item, ItemForm, ItemController, ItemService, ItemRepository, 예외
  config/     시작 주소 이동, dev 전용 예시 데이터
src/main/resources/
  application.yml / application-dev.yml
  db/migration/V1__create_items.sql
  templates/  한국어 품목 화면과 공통 레이아웃
  static/     Bootstrap CSS, 직접 작성한 CSS
src/test/     H2 및 MySQL 통합 검증
scripts/      Java 21 실행 도우미, 독립 MySQL 검증
docs/         계획, 현재 DB 구조, 코드 흐름, 검증 기록
```

- [전체 기능 계획과 업무 규칙](docs/plan.md)
- [현재 구현 DB 구조·ERD](docs/database.md)
- [실제 요청 → Controller → Service → Repository → DB 설명](docs/learning.md)
- [실행한 검증과 남은 검증](docs/verification.md)

Flyway가 `flyway_schema_history`에 적용 버전을 기록합니다. 이미 적용된 `V1`을 수정하는 대신 다음 변경은 `V2__...sql`로 추가합니다. JPA는 `ddl-auto: validate`로 스키마를 확인하며 테이블을 재생성하지 않습니다. 자동 데이터 삭제 SQL은 없습니다.

Git에는 소스·Wrapper·문서만 관리합니다. `.tools`, `.m2-local`, `target`, 접속 정보 파일은 제외합니다. 첫 단계가 끝나면 `git status --short`로 관리 대상을 확인하고 원하는 시점에 커밋하세요.
