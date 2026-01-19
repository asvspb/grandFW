#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/env_loader.sh"
source "$PROJECT_ROOT/tests/test_helpers.sh"

echo "=== Unit тесты: lib/env_loader.sh ==="

# Создаем временный .env для тестов
TEST_ENV="/tmp/test_env_$$.env"

# Тест load_env_safe: базовая загрузка
cat > "$TEST_ENV" << 'ENVEOF'
VAR1=value1
VAR2=value2
VAR3=value3
ENVEOF

run_test "load_env_safe: загрузка простых переменных" \
    'load_env_safe "$TEST_ENV" && [[ "$VAR1" == "value1" ]]'

# Тест load_env_safe: переменные с пробелами
cat > "$TEST_ENV" << 'ENVEOF'
VAR_WITH_SPACES="value with spaces"
ENVEOF

run_test "load_env_safe: переменные с пробелами" \
    'load_env_safe "$TEST_ENV" && [[ "$VAR_WITH_SPACES" == "value with spaces" ]]'

# Тест load_env_safe: комментарии игнорируются
cat > "$TEST_ENV" << 'ENVEOF'
# This is a comment
VAR_REAL=real_value
# Another comment
ENVEOF

run_test "load_env_safe: комментарии игнорируются" \
    'load_env_safe "$TEST_ENV" && [[ "$VAR_REAL" == "real_value" ]]'

# Тест load_env_safe: защита от command injection
cat > "$TEST_ENV" << 'ENVEOF'
SAFE_VAR=safe
MALICIOUS=$(echo "PWNED")
ENVEOF

run_test "load_env_safe: защита от command injection" \
    'load_env_safe "$TEST_ENV" && [[ "$MALICIOUS" == "\$(echo \"PWNED\")" ]]'

# Тест load_env_safe: несуществующий файл
run_test "load_env_safe: ошибка при несуществующем файле" \
    'assert_failure load_env_safe "/nonexistent/file.env"'

# Очистка
rm -f "$TEST_ENV"

print_test_summary