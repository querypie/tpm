# AWS Marketplace Custom EULA PDF

AWS Marketplace에 제출할 QueryPie Custom EULA PDF를 동일한 형식으로 다시 생성하고 검증하는 도구입니다.
법률 원문을 이 디렉토리에 복제하지 않고 `corp-web-v2`의 Markdown 파일을 직접 입력으로 사용합니다.

## 기준 정보

- 원문 기본 경로: `../../../../corp-web-v2/src/content/legal/eula/en/index.md`
- 최종 변경일: `2026-04-10`
- 법인명: `CHEQUER Global, Inc.`
- 출처: `https://www.querypie.com/eula`
- 출력 파일명: `eula-2026-04-10.pdf`

표지 제목은 `End User License Agreement` 한 줄로 표시하고 부제는 `QueryPie Software Products`로 표기합니다.
문서 버전은 표시하지 않으며 `Last updated: April 10, 2026`과 원문 출처 URL을 표시합니다.
PDF 생성일은 PDF 메타데이터에 별도로 기록되며 EULA 최종 변경일을 바꾸지 않습니다.
본문 페이지 푸터는 `Page X of Y` 형식으로 표시하여 문서의 마지막 페이지를 식별할 수 있게 합니다.

## 파일 구성

```text
aws/marketplace/eula/
├── .gitignore
├── README.md
├── Makefile
├── document.json
├── build_eula.py
├── template.py
├── verify_eula.py
├── test_eula.py
└── eula-2026-04-10.pdf  # 생성 파일, Git 제외
```

- `document.json`: 표지 정보와 마지막 변경일을 명시하는 고정 설정입니다.
- `template.py`: A4 표지, 본문, 머리글, 바닥글과 북마크 형식을 정의합니다.
- `build_eula.py`: Markdown을 읽고 PDF를 생성하는 CLI입니다.
- `verify_eula.py`: 원문과 PDF 본문이 일치하는지 검증합니다.
- `test_eula.py`: 최소 Markdown으로 원문 보존·생성·검증 흐름을 테스트합니다.

## 생성

먼저 Makefile이 있는 EULA 디렉토리로 이동한 후 모든 명령을 실행합니다.

```bash
cd aws/marketplace/eula
make pdf
```

기본 출력 파일은 Makefile과 같은 디렉토리의 `eula-2026-04-10.pdf`입니다.
이 디렉토리의 `.gitignore`에서 `*.pdf`와 `__pycache__/`를 제외합니다.
저장소 최상위 디렉토리나 별도 `output/` 디렉토리에는 산출물을 만들지 않습니다.

CLI를 직접 실행할 때도 EULA 디렉토리에서 실행합니다.

```bash
cd aws/marketplace/eula
./build_eula.py \
  --input ../../../../corp-web-v2/src/content/legal/eula/en/index.md \
  --output eula-2026-04-10.pdf
```

상대 경로는 Makefile이 있는 `aws/marketplace/eula/`를 기준으로 해석합니다.
원문에는 `../../../../corp-web-v2/...` 형식을 사용합니다.
CLI는 `--input`과 `--output`만 받습니다. 표지 정보는 같은 디렉토리의 `document.json`을 항상 사용하며 경로를 재정의하지 않습니다.

## 원문 보존 원칙

생성기는 입력 Markdown의 법률 문구를 수정하거나 주소를 교정하지 않습니다.
주소를 포함한 EULA 본문 변경은 `corp-web-v2`의 원문 변경으로만 수행합니다.
검증 명령은 입력 Markdown과 생성된 PDF 본문이 단어 단위로 완전히 일치하는지 확인합니다.

## 검증

```bash
make test
make verify
```

검증 명령은 다음 항목을 확인합니다.

- PDF가 암호화되지 않았는지
- 표지에 `Document version` 또는 `Document date`가 없는지
- 표지 제목이 한 줄이고 부제가 올바른 대소문자로 표시되는지
- 표지에 `Last updated: April 10, 2026`이 있는지
- 원문 출처 URL이 표시되고 클릭 가능한지
- 모든 본문 페이지가 `Page X of Y` 형식이며 마지막 페이지 번호가 전체 페이지 수와 일치하는지
- PDF 본문 전체가 입력 Markdown과 단어 단위로 일치하는지
- PDF 제목, 법인명과 Subject 메타데이터가 올바른지

생성된 PDF는 운영체제의 PDF 뷰어에서 직접 열어 검토합니다. 별도 미리보기 파일은 생성하지 않습니다.

## 변경 절차

1. 법무 승인된 EULA Markdown을 `corp-web-v2`에 먼저 반영합니다.
2. 마지막 변경일이 바뀌면 `document.json`을 함께 수정합니다.
3. 테스트와 검증을 실행합니다.
4. 렌더링된 전체 페이지를 확인합니다.
5. 검토가 끝난 PDF만 S3의 배포 대상 경로에 업로드합니다.
