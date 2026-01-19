#!/usr/bin/env bash
#
# backup.sh - Скрипт резервного копирования конфигурации grandFW
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Загрузка библиотек
source "$PROJECT_ROOT/lib/common.sh"

main() {
    log_info "=== Резервное копирование grandFW ==="
    
    check_root
    
    local backup_dir="${1:-$PROJECT_ROOT/backups}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="grandFW_backup_$timestamp"
    local backup_path="$backup_dir/$backup_name"
    
    mkdir -p "$backup_path"
    
    log_info "Создание резервной копии в $backup_path"
    
    # Копируем конфигурационные файлы
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        cp "$PROJECT_ROOT/.env" "$backup_path/"
        log_info "Скопирован .env файл"
    else
        log_warn ".env файл не найден"
    fi
    
    if [[ -f "$PROJECT_ROOT/xray_config.json" ]]; then
        cp "$PROJECT_ROOT/xray_config.json" "$backup_path/"
        log_info "Скопирован xray_config.json"
    fi
    
    if [[ -f "$PROJECT_ROOT/amnezia_client.conf" ]]; then
        cp "$PROJECT_ROOT/amnezia_client.conf" "$backup_path/"
        log_info "Скопирован amnezia_client.conf"
    fi
    
    if [[ -f "$PROJECT_ROOT/amnezia_server.conf" ]]; then
        cp "$PROJECT_ROOT/amnezia_server.conf" "$backup_path/"
        log_info "Скопирован amnezia_server.conf"
    fi
    
    if [[ -f "$PROJECT_ROOT/connection_guide.txt" ]]; then
        cp "$PROJECT_ROOT/connection_guide.txt" "$backup_path/"
        log_info "Скопирован connection_guide.txt"
    fi
    
    # Архивируем резервную копию
    local archive_name="$backup_dir/${backup_name}.tar.gz"
    tar -czf "$archive_name" -C "$backup_dir" "$backup_name"
    
    # Удаляем директорию после архивации
    rm -rf "$backup_path"
    
    log_info "Резервная копия создана: $archive_name"
    log_info "Размер архива: $(du -h "$archive_name" | cut -f1)"
    
    # Удаляем резервные копии старше 30 дней
    find "$backup_dir" -name "grandFW_backup_*.tar.gz" -mtime +30 -delete
    log_info "Старые резервные копии очищены"
    
    log_info "=== Резервное копирование завершено ==="
}

main "$@"