#!/usr/bin/env bash
#
# test_helpers.sh - Вспомогательные функции для тестов
#

# Цвета для вывода
readonly TEST_GREEN='\033[0;32m'
readonly TEST_RED='\033[0;31m'
readonly TEST_YELLOW='\033[1;33m'
readonly TEST_NC='\033[0m'

# Счетчики тестов
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

#######################################
# Запуск теста
# Arguments:
#   $1 - название теста
#   $2 - команда для выполнения
#######################################
run_test() {
    local test_name=$1
    shift
    local test_command="$@"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  [$TESTS_RUN] $test_name... "

    if eval "$test_command" &>/dev/null; then
        echo -e "${TEST_GREEN}✓ PASS${TEST_NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${TEST_RED}✗ FAIL${TEST_NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

#######################################
# Проверка равенства
#######################################
assert_equals() {
    local expected=$1
    local actual=$2
    [[ "$expected" == "$actual" ]]
}

#######################################
# Проверка, что строка не пустая
#######################################
assert_not_empty() {
    local value=$1
    [[ -n "$value" ]]
}

#######################################
# Проверка, что команда завершилась успешно
#######################################
assert_success() {
    "$@"
}

#######################################
# Проверка, что команда завершилась с ошибкой
#######################################
assert_failure() {
    ! "$@"
}

#######################################
# Проверка, что файл существует
#######################################
assert_file_exists() {
    local file=$1
    [[ -f "$file" ]]
}

#######################################
# Вывод итогов тестирования
#######################################
print_test_summary() {
    echo ""
    echo "================================"
    echo "Тестов запущено: $TESTS_RUN"
    echo -e "${TEST_GREEN}Успешно: $TESTS_PASSED${TEST_NC}"
    echo -e "${TEST_RED}Провалено: $TESTS_FAILED${TEST_NC}"
    echo "================================"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${TEST_GREEN}ВСЕ ТЕСТЫ ПРОЙДЕНЫ ✓${TEST_NC}"
        return 0
    else
        echo -e "${TEST_RED}ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ ✗${TEST_NC}"
        return 1
    fi
}

# Экспорт функций
export -f run_test assert_equals assert_not_empty
export -f assert_success assert_failure assert_file_exists
export -f print_test_summary