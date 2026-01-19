#!/usr/bin/env bash
#
# run_tests.sh - Главный test runner для grandFW
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Цвета
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Счетчики
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

#######################################
# Запуск тестового набора
#######################################
run_test_suite() {
    local suite_file=$1
    local suite_name=$(basename "$suite_file" .sh)

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Запуск: $suite_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if bash "$suite_file"; then
        echo -e "${GREEN}✓ $suite_name PASSED${NC}"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        echo -e "${RED}✗ $suite_name FAILED${NC}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

#######################################
# Главная функция
#######################################
main() {
    local test_type="${1:-all}"

    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   grandFW Test Suite Runner v3.0.0    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

    cd "$PROJECT_ROOT"

    case "$test_type" in
        unit)
            echo -e "${YELLOW}Запуск UNIT тестов...${NC}"
            for test in tests/unit/test_*.sh; do
                [[ -f "$test" ]] && run_test_suite "$test"
            done
            ;;
        
        integration)
            echo -e "${YELLOW}Запуск INTEGRATION тестов...${NC}"
            for test in tests/integration/test_*.sh; do
                [[ -f "$test" ]] && run_test_suite "$test"
            done
            ;;
        
        e2e)
            echo -e "${YELLOW}Запуск E2E тестов...${NC}"
            for test in tests/e2e/test_*.sh; do
                [[ -f "$test" ]] && run_test_suite "$test"
            done
            ;;
        
        all)
            echo -e "${YELLOW}Запуск ВСЕХ тестов...${NC}"

            # Unit тесты
            echo -e "\n${BLUE}═══ UNIT ТЕСТЫ ═══${NC}"
            for test in tests/unit/test_*.sh; do
                [[ -f "$test" ]] && run_test_suite "$test"
            done

            # Integration тесты
            echo -e "\n${BLUE}═══ INTEGRATION ТЕСТЫ ═══${NC}"
            for test in tests/integration/test_*.sh; do
                [[ -f "$test" ]] && run_test_suite "$test"
            done

            # E2E тесты (только если система настроена)
            if [[ -f .env ]]; then
                echo -e "\n${BLUE}═══ E2E ТЕСТЫ ═══${NC}"
                for test in tests/e2e/test_*.sh; do
                    [[ -f "$test" ]] && run_test_suite "$test"
                done
            else
                echo -e "\n${YELLOW}⚠ E2E тесты пропущены (.env не найден)${NC}"
            fi
            ;;
        
        *)
            echo "Использование: $0 [unit|integration|e2e|all]"
            exit 1
            ;;
    esac

    # Итоговый отчет
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ИТОГОВЫЙ ОТЧЕТ                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Всего тестовых наборов: $TOTAL_SUITES"
    echo -e "${GREEN}Успешно: $PASSED_SUITES${NC}"
    echo -e "${RED}Провалено: $FAILED_SUITES${NC}"
    echo ""

    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО ✓      ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        exit 0
    else
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║   ✗ ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ ✗          ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
}

main "$@"