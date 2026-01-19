#!/usr/bin/env bash
#
# uninstall.sh - Скрипт удаления grandFW
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Загрузка библиотек
source "$PROJECT_ROOT/lib/common.sh"

main() {
    log_info "=== Удаление grandFW ==="
    
    check_root
    
    read -p "Вы уверены, что хотите удалить grandFW? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Удаление отменено"
        exit 0
    fi
    
    # Остановка Docker контейнеров
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Остановка Docker контейнеров..."
        cd "$PROJECT_ROOT"
        docker compose down -v
        log_info "Контейнеры остановлены"
    else
        log_warn "docker-compose.yml не найден"
    fi
    
    # Удаление конфигурационных файлов
    log_info "Удаление конфигурационных файлов..."
    
    local config_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/xray_config.json"
        "$PROJECT_ROOT/amnezia_client.conf"
        "$PROJECT_ROOT/amnezia_server.conf"
        "$PROJECT_ROOT/connection_guide.txt"
        "$PROJECT_ROOT/configs"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_info "Удален файл: $file"
        elif [[ -d "$file" ]]; then
            rm -rf "$file"
            log_info "Удалена директория: $file"
        fi
    done
    
    # Удаление резервных копий
    log_info "Удаление резервных копий..."
    if [[ -d "$PROJECT_ROOT/backups" ]]; then
        rm -rf "$PROJECT_ROOT/backups"
        log_info "Директория резервных копий удалена"
    fi
    
    # Удаление логов
    log_info "Удаление логов..."
    if [[ -f "$PROJECT_ROOT/setup.log" ]]; then
        rm -f "$PROJECT_ROOT/setup.log"
        log_info "Лог setup удален"
    fi
    
    # Удаление правил UFW
    log_info "Удаление правил UFW..."
    if command -v ufw &> /dev/null; then
        # Удаляем предполагаемые правила (если они были добавлены)
        ufw delete allow 8443/tcp 2>/dev/null || true
        ufw delete allow 9443/tcp 2>/dev/null || true
        ufw delete allow 9443/udp 2>/dev/null || true
        ufw delete allow 51820/udp 2>/dev/null || true
        ufw delete allow 22/tcp 2>/dev/null || true
        
        log_info "Правила UFW удалены"
    else
        log_warn "UFW не установлен"
    fi
    
    log_info "=== Удаление завершено ==="
    log_info "grandFW успешно удален с системы"
}

main "$@"