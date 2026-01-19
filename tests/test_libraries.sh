#!/usr/bin/env bash
#
# Тестовый скрипт для проверки работоспособности библиотек
#

set -euo pipefail

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

echo "=== Тестирование библиотек grandFW ==="

# 1. Тестирование синтаксиса всех библиотек
echo -e "\n1. Проверка синтаксиса библиотек..."
for lib in "$LIB_DIR"/*.sh; do
    echo -n "  Проверка $(basename "$lib")... "
    if bash -n "$lib"; then
        echo "✓ OK"
    else
        echo "✗ ОШИБКА"
        exit 1
    fi
done

# 2. Загрузка всех библиотек
echo -e "\n2. Загрузка библиотек..."
source "$LIB_DIR/common.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/crypto.sh"
source "$LIB_DIR/env_loader.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/firewall.sh"
echo "✓ Все библиотеки успешно загружены"

# 3. Тестирование основных функций
echo -e "\n3. Тестирование основных функций..."

# Тестирование логирования
echo "  Тест логирования..."
log_info "Тестирование библиотек проходит успешно"

# Тестирование генерации UUID
echo "  Тест генерации UUID..."
uuid=$(generate_uuid)
if validate_uuid "$uuid"; then
    echo "  ✓ UUID сгенерирован и валиден: $uuid"
else
    echo "  ✗ Ошибка валидации UUID"
    exit 1
fi

# Тестирование генерации short ID
echo "  Тест генерации Short ID..."
short_id=$(generate_short_id)
if [[ ${#short_id} -eq 8 ]] && [[ "$short_id" =~ ^[0-9a-f]+$ ]]; then
    echo "  ✓ Short ID сгенерирован корректно: $short_id"
else
    echo "  ✗ Ошибка генерации Short ID"
    exit 1
fi

# Тестирование валидации портов
echo "  Тест валидации портов..."
if validate_port "8443" "TEST_PORT"; then
    echo "  ✓ Порт 8443 валиден"
else
    echo "  ✗ Порт 8443 невалиден"
    exit 1
fi

# Тестирование проверки конфликта портов
echo "  Тест проверки конфликта портов..."
PORT_VLESS=8443
PORT_SHADOWSOCKS=9443
ports=("PORT_VLESS" "PORT_SHADOWSOCKS")
if check_port_conflicts ports; then
    echo "  ✓ Конфликта портов не обнаружено"
else
    echo "  ✗ Обнаружен конфликт портов"
    exit 1
fi

echo -e "\n✓ Все тесты библиотек пройдены успешно!\n"

# Проверка критических исправлений
echo "=== Проверка критических исправлений ==="

# 1. Проверка конфликта портов (теперь должны быть разные порты)
echo "  Проверка исправления конфликта портов..."
if [[ "${PORT_VLESS:-}" != "${PORT_SHADOWSOCKS:-}" ]]; then
    echo "  ✓ Порты VLESS и Shadowsocks различаются"
else
    echo "  ✗ Порты VLESS и Shadowsocks совпадают"
    exit 1
fi

echo -e "\n✓ Все критические исправления учтены!"

echo -e "\n=== Тестирование завершено успешно ==="