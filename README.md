# grandFW - Мульти-протокольный VPN-сервер

[![Tests](https://github.com/asvspb/grandFW/actions/workflows/test.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/test.yml)
[![ShellCheck](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml)
[![Security](https://github.com/asvspb/grandFW/actions/workflows/security.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](CHANGELOG.md)

Модульная система установки и управления мульти-протокольным VPN-сервером с поддержкой следующих протоколов:
- VLESS + Reality
- Shadowsocks-2022
- AmneziaWG (WireGuard с обфускацией)

## Особенности

- ✅ **Модульная архитектура** - разделение на независимые библиотеки для лучшей поддержки
- ✅ **Автоматическая генерация криптографических параметров** - безопасная генерация ключей локально
- ✅ **Поддержка Docker и Docker Compose** - контейнеризированное развертывание
- ✅ **Безопасная загрузка переменных окружения** - защита от command injection уязвимостей
- ✅ **Автоматическая настройка брандмауэра (UFW)** - безопасная конфигурация firewall
- ✅ **Генерация QR-кодов для подключения** - быстрая настройка клиентов
- ✅ **Полное покрытие тестами** - unit, integration и E2E тесты
- ✅ **CI/CD интеграция** - автоматические проверки и деплои

## Требования

- **ОС**: Ubuntu 20.04+ (или совместимая система)
- **Права**: Root (для установки и настройки)
- **Порты**: 8443 (TCP), 9443 (TCP/UDP), 51820 (UDP) - должны быть открыты
- **Зависимости**: Docker, Docker Compose, WireGuard tools

## Установка

1. Клонируйте репозиторий или скачайте скрипт `setup.sh`
2. Убедитесь, что у вас есть root права
3. Запустите скрипт установки:

```bash
sudo ./setup.sh
```

### Повторный запуск

Для получения информации о подключении без перенастройки:

```bash
sudo ./setup.sh
```

## Архитектура

Проект использует модульную архитектуру с разделением на следующие библиотеки:

### Библиотеки (lib/)
- `lib/common.sh` - общие функции (логирование, проверки, backup)
- `lib/validation.sh` - валидация данных (UUID, IP, порты)
- `lib/crypto.sh` - криптографические функции
- `lib/env_loader.sh` - безопасная загрузка .env
- `lib/docker.sh` - работа с Docker
- `lib/firewall.sh` - настройка UFW

### Скрипты (scripts/)
- `scripts/setup.sh` - основной скрипт установки
- `scripts/health-check.sh` - проверка работоспособности
- `scripts/update.sh` - обновление конфигураций
- `scripts/backup.sh` - резервное копирование
- `scripts/uninstall.sh` - удаление

## Безопасность

### Защита от уязвимостей
- ✅ **Command injection защита** - безопасная загрузка .env файлов
- ✅ **Валидация всех входных данных** - проверка параметров
- ✅ **Ограничение прав доступа** - файл `.env` с правами 600
- ✅ **Проверка конфликтов портов** - предотвращение конфликтов

### Криптография
- ✅ **Генерация ключей локально** - безопасная генерация без отправки данных
- ✅ **Современные алгоритмы** - использование X25519, AES-128-GCM и т.д.
- ✅ **Проверка валидности ключей** - контроль корректности сгенерированных данных

## Поддерживаемые клиенты

### VLESS + Reality
- **Android**: Hiddify, v2rayNG, Shadowrocket, Qv2ray
- **iOS**: v2rayNG, Shadowrocket, Quantumult X, Loon
- **Windows**: Qv2ray, v2rayN
- **macOS**: Qv2ray, ClashX
- **Linux**: Qv2ray

### Shadowsocks-2022
- **Android**: Shadowsocks, v2rayNG
- **iOS**: Shadowrocket, Shadowsocks
- **Windows**: Shadowsocks Windows
- **macOS**: ShadowsocksX-NG
- **Linux**: shadowsocks-rust

### AmneziaWG
- **Все платформы**: AmneziaVPN, WireGuard clients

## Устранение неполадок

### Проверка состояния
```bash
# Состояние контейнеров
docker compose ps

# Логи Xray
docker compose logs xray

# Логи AmneziaWG
docker compose logs amnezia-wg

# Состояние firewall
sudo ufw status
```

### Распространенные проблемы
1. **Порт уже используется** - проверьте `sudo lsof -i :8443` и `sudo lsof -i :9443`
2. **Docker не запущен** - `sudo systemctl start docker`
3. **Нет доступа к .env файлу** - проверьте права: `ls -la .env`

Для подробного устранения неполадок смотрите [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Тестирование

### Запуск тестов
```bash
# Все тесты
./tests/run_tests.sh all

# Только unit тесты
./tests/run_tests.sh unit

# Только integration тесты
./tests/run_tests.sh integration
```

Проект полностью покрыт тестами:
- Unit тесты для каждой библиотеки
- Integration тесты для проверки взаимодействия компонентов
- E2E тесты для проверки реальных подключений

## CI/CD

Автоматическая проверка и развертывание:
- Запуск тестов при каждом push/PR
- Статический анализ кода (ShellCheck)
- Проверка безопасности
- Создание релизов при тегировании

## Лицензия

MIT License - см. файл [LICENSE](LICENSE) для подробностей.