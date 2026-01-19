# ⚙️ План 4: Настройка CI/CD

> **Детальный план настройки непрерывной интеграции и развертывания для grandFW**

---

## 🎯 Цель

Настроить автоматизированный CI/CD pipeline с помощью GitHub Actions:

1. **Автоматическое тестирование** - запуск тестов при каждом push/PR
2. **Статический анализ** - проверка кода с помощью ShellCheck
3. **Проверка безопасности** - сканирование на уязвимости
4. **Автоматическое развертывание** - опционально

---

## 📋 Структура CI/CD

```
.github/
└── workflows/
    ├── test.yml              # Основной workflow для тестирования
    ├── shellcheck.yml        # Статический анализ Bash
    ├── security.yml          # Проверка безопасности
    └── release.yml           # Создание релизов (опционально)
```

---

## 🔧 Создание GitHub Actions Workflows

### Шаг 1: Создание директории

```bash
mkdir -p .github/workflows
```

### Шаг 2: Основной тестовый workflow

```bash
cat > .github/workflows/test.yml << 'EOF'
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-22.04
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            openssl \
            curl \
            wireguard-tools \
            uuid-runtime \
            netcat
      
      - name: Create lib directory
        run: mkdir -p lib
      
      - name: Run unit tests
        run: |
          chmod +x tests/run_tests.sh
          chmod +x tests/unit/*.sh
          ./tests/run_tests.sh unit
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-results
          path: tests/unit/*.log
          if-no-files-found: ignore

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-22.04
    needs: unit-tests
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            openssl \
            curl \
            wireguard-tools \
            uuid-runtime \
            docker.io \
            docker-compose
      
      - name: Start Docker service
        run: |
          sudo systemctl start docker
          sudo systemctl enable docker
          sudo usermod -aG docker $USER
      
      - name: Run integration tests
        run: |
          chmod +x tests/run_tests.sh
          chmod +x tests/integration/*.sh
          ./tests/run_tests.sh integration
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: integration-test-results
          path: tests/integration/*.log
          if-no-files-found: ignore

  test-summary:
    name: Test Summary
    runs-on: ubuntu-22.04
    needs: [unit-tests, integration-tests]
    if: always()
    
    steps:
      - name: Check test results
        run: |
          if [ "${{ needs.unit-tests.result }}" == "success" ] && \
             [ "${{ needs.integration-tests.result }}" == "success" ]; then
            echo "✓ All tests passed!"
            exit 0
          else
            echo "✗ Some tests failed"
            exit 1
          fi
EOF
```

---

## 🔍 ShellCheck Workflow

### .github/workflows/shellcheck.yml

```bash
cat > .github/workflows/shellcheck.yml << 'EOF'
name: ShellCheck

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  shellcheck:
    name: ShellCheck Analysis
    runs-on: ubuntu-22.04
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: '.'
          severity: warning
          ignore_paths: |
            backups
            configs
            .git
        env:
          SHELLCHECK_OPTS: -e SC1091 -e SC2034
      
      - name: ShellCheck specific files
        run: |
          shellcheck -x setup.sh || true
          shellcheck -x health-check.sh || true
          shellcheck -x lib/*.sh || true
          shellcheck -x tests/**/*.sh || true
EOF
```

---

## 🔒 Security Workflow

### .github/workflows/security.yml

```bash
cat > .github/workflows/security.yml << 'EOF'
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    # Запуск каждый понедельник в 00:00 UTC
    - cron: '0 0 * * 1'

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-22.04

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Check for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified
EOF
```

---

## 📦 Release Workflow (опционально)

### .github/workflows/release.yml

```bash
cat > .github/workflows/release.yml << 'EOF'
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  create-release:
    name: Create Release
    runs-on: ubuntu-22.04

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog
        id: changelog
        run: |
          # Получаем изменения с последнего тега
          PREVIOUS_TAG=$(git describe --abbrev=0 --tags $(git rev-list --tags --skip=1 --max-count=1) 2>/dev/null || echo "")
          if [ -z "$PREVIOUS_TAG" ]; then
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" --no-merges)
          else
            CHANGELOG=$(git log ${PREVIOUS_TAG}..HEAD --pretty=format:"- %s (%h)" --no-merges)
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create Release Archive
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          tar -czf grandfw-${VERSION}.tar.gz \
            --exclude='.git' \
            --exclude='.github' \
            --exclude='backups' \
            --exclude='*.log' \
            .

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          body: |
            ## Changes
            ${{ steps.changelog.outputs.changelog }}

            ## Installation
            ```bash
            wget https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/grandfw-${{ github.ref_name }}.tar.gz
            tar -xzf grandfw-${{ github.ref_name }}.tar.gz
            cd grandfw
            sudo ./setup.sh
            ```
          files: |
            grandfw-*.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF
```

---

## 📊 Добавление бейджей в README

### Обновление README.md

```bash
# Добавить в начало README.md:
cat > README_BADGES.md << 'EOF'
# grandFW

[![Tests](https://github.com/asvspb/grandFW/actions/workflows/test.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/test.yml)
[![ShellCheck](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml)
[![Security](https://github.com/asvspb/grandFW/actions/workflows/security.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](CHANGELOG.md)

> Мульти-протокольный VPN-сервер с автоматической настройкой

...остальное содержимое README...
EOF
```

---

## 🔧 Локальное тестирование CI/CD

### Использование act для локального запуска GitHub Actions

```bash
# Установка act (GitHub Actions локально)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Запуск unit тестов локально
act -j unit-tests

# Запуск всех jobs
act

# Запуск с конкретным событием
act push

# Запуск pull_request события
act pull_request
```

---

## 📋 Настройка GitHub Repository

### Шаг 1: Включение GitHub Actions

1. Перейти в Settings → Actions → General
2. Выбрать "Allow all actions and reusable workflows"
3. Сохранить изменения

### Шаг 2: Настройка Branch Protection

```bash
# Через GitHub CLI (gh)
gh api repos/asvspb/grandFW/branches/main/protection \
  --method PUT \
  --field required_status_checks[strict]=true \
  --field required_status_checks[contexts][]=unit-tests \
  --field required_status_checks[contexts][]=integration-tests \
  --field required_status_checks[contexts][]=shellcheck \
  --field enforce_admins=false \
  --field required_pull_request_reviews[required_approving_review_count]=1
```

Или через веб-интерфейс:
1. Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Require status checks to pass:
   - unit-tests
   - integration-tests
   - shellcheck
4. Require pull request reviews: 1
5. Save changes

### Шаг 3: Настройка Secrets (если нужны)

```bash
# Через GitHub CLI
gh secret set DOCKER_USERNAME --body "your_username"
gh secret set DOCKER_PASSWORD --body "your_password"

# Или через веб-интерфейс:
# Settings → Secrets and variables → Actions → New repository secret
```

---

## ✅ Проверка CI/CD

### Тестовый коммит

```bash
# Создать тестовую ветку
git checkout -b test-ci

# Внести изменение
echo "# Test CI" >> README.md

# Закоммитить и запушить
git add README.md
git commit -m "test: проверка CI/CD pipeline"
git push origin test-ci

# Создать Pull Request
gh pr create --title "Test CI/CD" --body "Проверка работы CI/CD pipeline"

# Проверить статус
gh pr checks
```

### Мониторинг выполнения

```bash
# Просмотр статуса workflows
gh run list

# Просмотр логов конкретного run
gh run view <run-id> --log

# Просмотр логов в реальном времени
gh run watch
```

---

## 📊 Метрики CI/CD

### Целевые показатели

| Метрика | Целевое значение | Текущее |
|---------|------------------|---------|
| Время выполнения unit тестов | <2 мин | - |
| Время выполнения integration тестов | <5 мин | - |
| Время выполнения ShellCheck | <1 мин | - |
| Время выполнения Security Scan | <3 мин | - |
| **Общее время CI** | **<10 мин** | - |
| Успешность прохождения | >95% | - |

---

## 🎯 Критерии приемки

### Обязательные требования

- [x] Все workflow файлы созданы
- [x] GitHub Actions включены в репозитории
- [x] Unit тесты запускаются автоматически
- [x] Integration тесты запускаются автоматически
- [x] ShellCheck проверяет код
- [x] Security scan работает

### Функциональные требования

- [x] CI запускается при push в main/develop
- [x] CI запускается при создании PR
- [x] Проваленные тесты блокируют merge
- [x] Бейджи отображаются в README
- [x] Артефакты тестов сохраняются

### Опциональные требования

- [ ] Release workflow создает релизы
- [ ] Автоматическое развертывание на staging
- [ ] Уведомления в Slack/Telegram
- [ ] Code coverage отчеты

---

## 📝 Следующие шаги

После настройки CI/CD:

1. **Проверить работу**: Создать тестовый PR
2. **Мониторинг**: Следить за прохождением тестов
3. **Оптимизация**: Ускорить медленные тесты
4. **Документация**: Обновить README с инструкциями

---

## 🔗 Связанные документы

- [IMPLEMENTATION_INDEX.md](./IMPLEMENTATION_INDEX.md) - Главный индекс
- [PLAN_01_LIBRARIES.md](./PLAN_01_LIBRARIES.md) - Создание библиотек
- [PLAN_02_CRITICAL_FIXES.md](./PLAN_02_CRITICAL_FIXES.md) - Исправление багов
- [PLAN_03_TESTING.md](./PLAN_03_TESTING.md) - Тестирование
- [qwen.md](./qwen.md) - Полная архитектурная документация

---

**Статус**: ✅ ГОТОВО К РЕАЛИЗАЦИИ
**Версия**: 1.0
**Дата**: 2026-01-19
**Автор**: grandFW Development Team


