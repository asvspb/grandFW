#!/usr/bin/env bash
#
# update.sh - Скрипт обновления конфигурации grandFW
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Загрузка библиотек
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/validation.sh"
source "$PROJECT_ROOT/lib/env_loader.sh"

main() {
    log_info "=== Обновление конфигурации grandFW ==="
    
    check_root
    
    if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
        log_error "Файл .env не найден. Запустите сначала setup.sh"
        exit 1
    fi
    
    # Загружаем текущую конфигурацию
    load_env_safe "$PROJECT_ROOT/.env"
    
    log_info "Текущая конфигурация загружена"
    
    # Проверяем валидность текущей конфигурации
    if ! validate_env_vars; then
        log_error "Текущая конфигурация содержит ошибки"
        exit 1
    fi
    
    log_info "Конфигурация валидна"
    
    # Перезапускаем Docker контейнеры с новой конфигурацией
    if command -v docker &> /dev/null && [[ -f docker-compose.yml ]]; then
        log_info "Перезапуск Docker контейнеров..."
        docker compose down
        docker compose up -d
        log_info "Контейнеры перезапущены"
    else
        log_warn "Docker не установлен или docker-compose.yml не найден"
    fi
    
    log_info "=== Обновление завершено ==="
}

main "$@"