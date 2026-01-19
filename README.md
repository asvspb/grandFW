# Мульти-протокольный VPN-сервер

[![Tests](https://github.com/asvspb/grandFW/actions/workflows/test.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/test.yml)
[![ShellCheck](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/shellcheck.yml)
[![Security](https://github.com/asvspb/grandFW/actions/workflows/security.yml/badge.svg)](https://github.com/asvspb/grandFW/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](CHANGELOG.md)

Скрипт для установки и управления мульти-протокольным VPN-сервером с поддержкой следующих протоколов:
- VLESS + Reality
- Shadowsocks-2022
- AmneziaWG

## Особенности

- Автоматическая генерация криптографических ключей и параметров
- Поддержка Docker и Docker Compose
- Автоматическая настройка брандмауэра (UFW)
- Генерация QR-кодов для быстрой настройки клиентов
- Поддержка современных протоколов обхода блокировок
- Модульная архитектура с разделением на библиотеки
- Полностью покрыт тестами
- Безопасная загрузка переменных окружения
- Защита от command injection уязвимостей

## Требования

- Ubuntu 20.04+ (или совместимая система)
- Root права
- Открытые порты: 8443 (TCP) и 51820 (UDP)

## Установка

1. Убедитесь, что у вас есть root права или права sudo
2. Склонируйте репозиторий или скачайте скрипт `setup.sh`
3. Запустите скрипт с root правами:

```bash
sudo ./setup.sh
```

Скрипт автоматически:
- Проверит и установит необходимые зависимости
- Сгенерирует криптографические ключи
- Создаст конфигурационные файлы
- Настроит брандмауэр
- Запустит VPN-сервисы
- Покажет информацию для подключения

## Повторный запуск

Если вам нужно повторно получить информацию для подключения:

```bash
sudo ./setup.sh --info
```

## Безопасность

- Все конфиденциальные данные генерируются локально
- Ключи хранятся в файле `.env` с ограниченным доступом (600)
- Используются современные методы шифрования
- Защита от command injection уязвимостей
- Валидация всех входных данных

## Поддерживаемые клиенты

### VLESS + Reality
- **Android**: Hiddify, v2rayNG, Shadowrocket, Qv2ray и другие
- **iOS**: v2rayNG, Shadowrocket, Quantumult X, Loon
- **Windows**: Qv2ray, v2rayN
- **macOS**: Qv2ray, ClashX
- **Linux**: Qv2ray

### Shadowsocks-2022
- **Android**: Shadowsocks-клиенты с поддержкой AEAD-шифрования
- **iOS**: Shadowsocks
- **Windows**: Shadowsocks-клиенты
- **macOS**: ShadowsocksX-NG
- **Linux**: shadowsocks-rust

### AmneziaWG
- **Все платформы**: AmneziaVPN

## Устранение неполадок

Если возникают проблемы с подключением:
1. Проверьте, что порты открыты в брандмауэре
2. Убедитесь, что службы запущены: `docker compose ps`
3. Посмотрите логи: `docker compose logs xray` и `docker compose logs amnezia-wg`

## Лицензия

MIT License - см. файл LICENSE для подробностей.

## Архитектура

Проект использует модульную архитектуру с разделением на следующие библиотеки:
- `lib/common.sh` - общие функции (логирование, проверки, backup)
- `lib/validation.sh` - валидация данных (UUID, IP, порты)
- `lib/crypto.sh` - криптографические функции
- `lib/env_loader.sh` - безопасная загрузка .env
- `lib/docker.sh` - работа с Docker
- `lib/firewall.sh` - настройка UFW

## Тестирование

Проект полностью покрыт тестами:
- Unit тесты для каждой библиотеки
- Integration тесты для проверки взаимодействия компонентов
- E2E тесты для проверки реальных подключений

Запуск всех тестов:
```bash
./tests/run_tests.sh all
```

## CI/CD

Автоматическая проверка и развертывание:
- Запуск тестов при каждом push/PR
- Статический анализ кода (ShellCheck)
- Проверка безопасности
- Создание релизов при тегировании