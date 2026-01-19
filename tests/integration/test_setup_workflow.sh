#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/crypto.sh"
source "$PROJECT_ROOT/lib/validation.sh"
source "$PROJECT_ROOT/lib/env_loader.sh"
source "$PROJECT_ROOT/tests/test_helpers.sh"

echo "=== Integration тесты: Setup Workflow ==="

# Создаем временную директорию для тестов
TEST_DIR="/tmp/grandfw_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Тест: Генерация всех секретов
run_test "generate_all_secrets: генерация всех параметров" \
    'generate_all_secrets'

# Тест: Валидация сгенерированных параметров
run_test "Валидация UUID после генерации" \
    'validate_uuid "$UUID"'

run_test "Валидация портов по умолчанию" \
    'PORT_VLESS=8443 && PORT_SHADOWSOCKS=9443 && validate_port "$PORT_VLESS" "TEST" && validate_port "$PORT_SHADOWSOCKS" "TEST"'

run_test "Проверка отсутствия конфликтов портов" \
    'PORT_VLESS=8443 && PORT_SHADOWSOCKS=9443 && ports=("PORT_VLESS" "PORT_SHADOWSOCKS") && check_port_conflicts ports'

# Тест: Сохранение и загрузка .env
run_test "save_env_file: сохранение конфигурации" \
    'SERVER_NAME=test.com && SNI=test.com && EXTERNAL_IP=1.2.3.4 && save_env_file "$TEST_DIR/.env"'

run_test "Проверка прав доступа .env (600)" \
    '[[ $(stat -c "%a" "$TEST_DIR/.env") == "600" ]]'

run_test "load_env_safe: загрузка сохраненной конфигурации" \
    'unset UUID && load_env_safe "$TEST_DIR/.env" && assert_not_empty "$UUID"'

# Очистка
cd /
rm -rf "$TEST_DIR"

print_test_summary