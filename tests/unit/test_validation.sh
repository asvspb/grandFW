#!/usr/bin/env bash
#
# test_validation.sh - Unit тесты для lib/validation.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Загрузка библиотек
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/validation.sh"
source "$PROJECT_ROOT/tests/test_helpers.sh"

echo "=== Unit тесты: lib/validation.sh ==="

# Тест validate_uuid
run_test "validate_uuid: валидный UUID" \
    validate_uuid "550e8400-e29b-41d4-a716-446655440000"

run_test "validate_uuid: невалидный UUID (короткий)" \
    'assert_failure validate_uuid "550e8400"'

run_test "validate_uuid: невалидный UUID (неверный формат)" \
    'assert_failure validate_uuid "not-a-uuid"'

run_test "validate_uuid: пустой UUID" \
    'assert_failure validate_uuid ""'

# Тест validate_port
run_test "validate_port: валидный порт 8443" \
    validate_port "8443" "TEST"

run_test "validate_port: валидный порт 1" \
    validate_port "1" "TEST"

run_test "validate_port: валидный порт 65535" \
    validate_port "65535" "TEST"

run_test "validate_port: невалидный порт 0" \
    'assert_failure validate_port "0" "TEST"'

run_test "validate_port: невалидный порт 65536" \
    'assert_failure validate_port "65536" "TEST"'

run_test "validate_port: невалидный порт (не число)" \
    'assert_failure validate_port "abc" "TEST"'

# Тест validate_ip
run_test "validate_ip: валидный IP 192.168.1.1" \
    validate_ip "192.168.1.1"

run_test "validate_ip: валидный IP 8.8.8.8" \
    validate_ip "8.8.8.8"

run_test "validate_ip: невалидный IP (октет > 255)" \
    'assert_failure validate_ip "192.168.1.256"'

run_test "validate_ip: невалидный IP (неверный формат)" \
    'assert_failure validate_ip "not.an.ip.address"'

run_test "validate_ip: пустой IP" \
    'assert_failure validate_ip ""'

# Тест validate_domain
run_test "validate_domain: валидный домен google.com" \
    validate_domain "google.com"

run_test "validate_domain: валидный домен www.example.org" \
    validate_domain "www.example.org"

run_test "validate_domain: невалидный домен (без TLD)" \
    'assert_failure validate_domain "localhost"'

print_test_summary