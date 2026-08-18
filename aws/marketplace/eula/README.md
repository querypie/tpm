# AWS Marketplace Custom EULA PDF

AWS Marketplace에 제출할 QueryPie Custom EULA PDF를 동일한 형식으로 다시 생성하고 검증하는 도구입니다.
법률 원문을 이 디렉토리에 복제하지 않고 `corp-web-v2`의 Markdown 파일을 직접 입력으로 사용합니다.

## 기준 정보

- 원문 기본 경로: `../corp-web-v2/src/content/legal/eula/en/index.md`
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
├── README.md
├── Makefile
├── document.json
├── build_eula.py
├── template.py
├── verify_eula.py
└── test_eula.py
```

- `document.json`: 표지 정보와 마지막 변경일을 명시합니다.
- `template.py`: A4 표지, 본문, 머리글, 바닥글과 북마크 형식을 정의합니다.
- `build_eula.py`: Markdown을 읽고 PDF를 생성하는 CLI입니다.
- `verify_eula.py`: 원문과 PDF 본문이 일치하는지 검증합니다.
- `test_eula.py`: 최소 Markdown으로 원문 보존·생성·검증 흐름을 테스트합니다.

## 생성

저장소 루트에서 다음 명령을 실행합니다.

```bash
make -C aws/marketplace/eula pdf
```

기본 출력 위치는 `output/pdf/eula-2026-04-10.pdf`입니다.
`output/`과 `tmp/`는 로컬 검토 산출물이므로 Git에 포함하지 않습니다.

CLI를 직접 실행하면서 상대 경로를 지정할 수도 있습니다.

```bash
./aws/marketplace/eula/build_eula.py \
  --input ../corp-web-v2/src/content/legal/eula/en/index.md \
  --output output/pdf/eula-2026-04-10.pdf
```

임시로 복제한 Markdown도 같은 방식으로 사용할 수 있습니다.

```bash
./aws/marketplace/eula/build_eula.py \
  --input /tmp/querypie-marketplace-eula.md \
  --output output/pdf/eula-2026-04-10.pdf
```

상대 경로는 명령을 실행한 현재 디렉토리를 기준으로 해석합니다.
Makefile은 저장소 루트에서 명령을 실행하므로 `../corp-web-v2/...` 형식을 그대로 사용할 수 있습니다.
`CONFIG`를 재정의할 때 상대 경로는 저장소 루트를 기준으로 해석하며, 절대 경로도 사용할 수 있습니다.

```bash
make -C aws/marketplace/eula pdf \
  CONFIG=aws/marketplace/eula/document.json
```

## 원문 보존 원칙

생성기는 입력 Markdown의 법률 문구를 수정하거나 주소를 교정하지 않습니다.
주소를 포함한 EULA 본문 변경은 `corp-web-v2`의 원문 변경으로만 수행합니다.
검증 명령은 입력 Markdown과 생성된 PDF 본문이 단어 단위로 완전히 일치하는지 확인합니다.

## 검증

```bash
make -C aws/marketplace/eula test
make -C aws/marketplace/eula verify
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

페이지를 PNG로 렌더링해 검토하려면 Poppler의 `pdftoppm`이 설치된 환경에서 실행합니다.

```bash
make -C aws/marketplace/eula preview
```

## 변경 절차

1. 법무 승인된 EULA Markdown을 `corp-web-v2`에 먼저 반영합니다.
2. 마지막 변경일이 바뀌면 `document.json`을 함께 수정합니다.
3. 테스트와 검증을 실행합니다.
4. 렌더링된 전체 페이지를 확인합니다.
5. 검토가 끝난 PDF만 S3의 배포 대상 경로에 업로드합니다.
