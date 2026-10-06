# claude-statusline

Windows용 Claude Code 상태 표시줄입니다.

```
📁 project | 🌿 main ●3 | Opus 5.5 | ctx 42% | $0.42 | 5h 23% (11:28) | 7d 61% (10/09) | 🕐 13:20
```

| 항목 | 설명 |
| --- | --- |
| 📁 | 현재 폴더 |
| 🌿 | Git 브랜치 · 변경 파일 수 |
| 모델 | 사용 중인 모델 |
| ctx | 컨텍스트 사용률 |
| $ | 세션 비용 (API 요금 환산, 구독 사용자는 참고용) |
| 5h / 7d | 5시간 · 7일 사용 한도 사용률 (리셋 시각) |
| 🕐 | 세션 시작 시각 |

퍼센트는 50% 미만 초록, 50~79% 노랑, 80% 이상 빨강으로 표시됩니다.

## 설치

PowerShell에서 한 줄로:

```powershell
irm https://raw.githubusercontent.com/DevJunz/claude-statusline/main/install.ps1 | iex
```

또는 저장소를 받아서:

```powershell
git clone https://github.com/DevJunz/claude-statusline
cd claude-statusline
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

설치 스크립트는 `~/.claude/statusline.ps1`을 복사하고 `~/.claude/settings.json`의 `statusLine`만 설정합니다. 다른 설정은 그대로 두며, 기존 파일은 `settings.json.bak`으로 백업합니다. 설치 후 Claude Code를 다시 시작하세요.

## 업데이트

`statusline.ps1`을 수정해 push한 뒤, 다른 PC에서 설치 명령을 다시 실행하면 됩니다.
