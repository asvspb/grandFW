#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/crypto.sh"
source "$PROJECT_ROOT/lib/validation.sh"
source "$PROJECT_ROOT/tests/test_helpers.sh"

echo "=== Unit тесты: lib/crypto.sh ==="

# Тест generate_uuid
run_test "generate_uuid: генерация UUID" \
    'uuid=$(generate_uuid) && validate_uuid "$uuid"'

run_test "generate_uuid: UUID не пустой" \
    'uuid=$(generate_uuid) && assert_not_empty "$uuid"'

# Тест generate_short_id
run_test "generate_short_id: генерация Short ID" \
    'short_id=$(generate_short_id) && assert_not_empty "$short_id"'

run_test "generate_short_id: длина 8 символов" \
    'short_id=$(generate_short_id) && [[ ${#short_id} -eq 8 ]]'

run_test "generate_short_id: только hex символы" \
    'short_id=$(generate_short_id) && [[ "$short_id" =~ ^[0-9a-f]{8}$ ]]'

# Тест generate_ss_password
run_test "generate_ss_password: генерация пароля" \
    'password=$(generate_ss_password) && assert_not_empty "$password"'

run_test "generate_ss_password: base64 формат" \
    'password=$(generate_ss_password) && echo "$password" | base64 -d &>/dev/null'

# Тест generate_wg_keys (требует wireguard-tools)
if command -v wg &>/dev/null; then
    run_test "generate_wg_keys: генерация ключей" \
        'keys=($(generate_wg_keys)) && [[ ${#keys[@]} -eq 2 ]]'

    run_test "generate_wg_keys: приватный ключ не пустой" \
        'keys=($(generate_wg_keys)) && assert_not_empty "${keys[0]}"'

    run_test "generate_wg_keys: публичный ключ не пустой" \
        'keys=($(generate_wg_keys)) && assert_not_empty "${keys[1]}"'
else
    echo "  ⚠ Пропущены тесты WireGuard (wg не установлен)"
fi

# Тест generate_random_number
run_test "generate_random_number: число в диапазоне 1-10" \
    'num=$(generate_random_number 1 10) && [[ $num -ge 1 && $num -le 10 ]]'

run_test "generate_random_number: число в диапазоне 100-200" \
    'num=$(generate_random_number 100 200) && [[ $num -ge 100 && $num -le 200 ]]'

print_test_summary