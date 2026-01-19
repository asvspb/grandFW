# Решение проблем (Troubleshooting)

## Общие проблемы

### 1. Ошибка установки зависимостей

**Проблема**: Установка зависимостей завершается с ошибкой

**Решение**:
1. Обновите систему: `sudo apt update && sudo apt upgrade`
2. Проверьте подключение к интернету
3. Запустите установку снова: `sudo ./setup.sh`
4. Если проблема сохраняется, установите зависимости вручную:
   ```bash
   sudo apt install -y docker.io docker-compose-plugin curl openssl wireguard-tools qrencode gettext-base uuid-runtime
   ```

### 2. Порт уже используется

**Проблема**: Ошибка "Port is already allocated"

**Решение**:
1. Проверьте, что использует порт: `sudo lsof -i :8443`, `sudo lsof -i :9443`, `sudo lsof -i :51820`
2. Остановите конфликтующее приложение
3. Перезапустите установку

### 3. Docker не запускается

**Проблема**: Ошибка при запуске Docker контейнеров

**Решение**:
1. Запустите Docker вручную: `sudo systemctl start docker`
2. Проверьте статус: `sudo systemctl status docker`
3. Если не помогает, перезапустите систему
4. Убедитесь, что установлены правильные версии Docker и Docker Compose:
   ```bash
   docker --version
   docker compose version  # Обратите внимание: не docker-compose (старая версия)
   ```

### 4. Docker Compose не найден

**Проблема**: Ошибка "docker compose: command not found"

**Решение**:
1. Установите плагин Docker Compose:
   ```bash
   sudo apt install docker-compose-plugin
   ```
2. Или используйте альтернативный путь:
   ```bash
   sudo apt install docker-compose-v2
   ```

## Проблемы с подключением

### 1. Клиент не может подключиться к VLESS

**Проверьте**:
- Порт 8443 открыт в firewall: `sudo ufw status`
- Контейнер xray запущен: `docker compose -p grandfw ps`
- Серверное имя (SNI) правильно настроено
- Сертификаты действительны

**Решения**:
1. Проверьте логи: `docker compose -p grandfw logs xray`
2. Убедитесь, что DNS настроен правильно
3. Попробуйте использовать другое доменное имя для SNI

### 2. Клиент не может подключиться к Shadowsocks

**Проверьте**:
- Порт 9443 открыт в firewall (TCP и UDP)
- Контейнер xray запущен
- Пароль корректен

**Решения**:
1. Проверьте логи: `docker compose -p grandfw logs xray`
2. Убедитесь, что используете правильный метод шифрования (2022-blake3-aes-128-gcm)

### 3. Клиент не может подключиться к AmneziaWG

**Проверьте**:
- Порт 51820/udp открыт в firewall
- Контейнер amnezia-wg запущен
- Конфигурация корректна
- Внешний IP в конфиге правильный

**Решения**:
1. Проверьте логи: `docker compose -p grandfw logs amnezia-wg`
2. Убедитесь, что IP-адрес в конфиге правильный
3. Проверьте, что UDP-трафик не блокируется провайдером

## Проблемы с безопасностью

### 1. Command injection уязвимость (исправлена)

**Проблема**: Ранее существовала уязвимость в загрузке .env файлов

**Решение**: 
- Используется безопасная функция `load_env_safe()` из `lib/env_loader.sh`
- Никогда не используйте `export $(grep -v '^#' .env | xargs)` - это уязвимо!

### 2. Небезопасные права доступа к .env (исправлено)

**Проблема**: Файл .env ранее был доступен для чтения другими пользователями

**Решение**:
- Файл .env автоматически защищен правами доступа 600 при создании
- Владелец файла: root:root
- Проверить права: `ls -la .env`

## Диагностика и отладка

### 1. Проверка состояния сервисов

```bash
# Проверка состояния контейнеров
docker compose -p grandfw ps

# Проверка логов xray
docker compose -p grandfw logs xray

# Проверка логов amnezia-wg
docker compose -p grandfw logs amnezia-wg

# Проверка открытых портов
sudo ss -tulnp | grep -E "(8443|9443|51820)"

# Проверка firewall правил
sudo ufw status
```

### 2. Запуск диагностики

```bash
# Запуск скрипта диагностики
sudo ./scripts/health-check.sh

# Запуск тестов
./tests/run_tests.sh all
```

### 3. Проверка конфигурации

```bash
# Проверка синтаксиса конфигурации xray
docker run --rm -i teddysun/xray xray -test -config=/dev/stdin < xray_config.json

# Проверка .env файла
source lib/env_loader.sh
load_env_safe .env
```

### 4. Проверка валидации

```bash
# Запуск валидации переменных окружения
source lib/validation.sh
validate_env_vars
```

## Восстановление

### 1. Восстановление из резервной копии

```bash
# Восстановление .env файла из резервной копии
sudo cp backups/.env.backup.date .env
sudo chmod 600 .env

# Перезапуск сервисов
docker compose -p grandfw down && docker compose -p grandfw up -d
```

### 2. Сброс конфигурации

```bash
# Остановка сервисов
docker compose -p grandfw down

# Удаление конфигурационных файлов
rm -f .env xray_config.json amnezia_*.conf connection_guide.txt

# Удаление директории configs если она существует
rm -rf configs/

# Перезапуск установки
sudo ./setup.sh
```

### 3. Пересоздание конфигурации

```bash
# Удаление старых конфигов
rm -f xray_config.json amnezia_*.conf

# Перезапуск скрипта установки (он пересоздаст конфиги)
sudo ./setup.sh
```

## Отладка в режиме DEBUG

Для включения отладки установите переменную DEBUG:

```bash
export DEBUG=true
sudo ./setup.sh
```

Или добавьте в .env файл:

```bash
DEBUG=true
```

### Включение отладки для конкретных библиотек

```bash
# Отладка валидации
DEBUG=true ./tests/unit/test_validation.sh

# Отладка криптографии
DEBUG=true ./tests/unit/test_crypto.sh
```

## Распространенные ошибки и решения

### Ошибка: "permission denied" при работе с Docker

**Причина**: Пользователь не в группе docker

**Решение**:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Ошибка: "command not found: docker-compose"

**Причина**: Используется старый синтаксис (через дефис)

**Решение**: Используйте новый синтаксис (через пробел):
```bash
# Правильно
docker compose up

# Неправильно (старый способ)
docker-compose up
```

### Ошибка: "port is already allocated"

**Причина**: Порт уже используется другим процессом или старым контейнером

**Решение**:
```bash
# Найти процессы, использующие порт
sudo lsof -i :8443

# Удалить оставшиеся контейнеры
docker ps -a | grep -E "(xray|amnezia)" | awk '{print $1}' | xargs -r docker rm -f

# Перезапустить установку
sudo ./setup.sh
```

### Ошибка: "failed to create process" или "command not found"

**Причина**: Проблемы с правами доступа к файлам или отсутствие зависимостей

**Решение**:
1. Проверьте права доступа к файлам:
   ```bash
   ls -la setup.sh
   ```
2. Убедитесь, что файл исполняемый:
   ```bash
   chmod +x setup.sh
   ```

## Поддержка

Если проблемы не удается решить самостоятельно:

1. Проверьте существующие issue: https://github.com/asvspb/grandFW/issues
2. Запустите диагностику: `sudo ./scripts/health-check.sh`
3. Запустите тесты: `./tests/run_tests.sh all`
4. Создайте новое issue с описанием проблемы
5. Приложите логи и вывод команд диагностики
6. Укажите версию системы и компонентов

### Сбор информации для отладки

```bash
# Собрать информацию о системе
echo "System Info:"
uname -a
echo -e "\nDocker versions:"
docker --version
docker compose version
echo -e "\nContainer status:"
docker compose -p grandfw ps
echo -e "\nNetwork status:"
sudo ufw status
echo -e "\nExternal IP:"
curl -s https://api.ipify.org
```

Контакты:
- Email: asvdevpro@gmail.com
- GitHub Issues: https://github.com/asvspb/grandFW/issues