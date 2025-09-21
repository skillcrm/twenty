# Настройка статической конфигурации для GitHub Actions

## Быстрый старт

### 1. Запустите автоматический скрипт

```bash
cd packages/twenty-docker/k8s
./get-github-secrets.sh
```

### 2. Скопируйте полученные данные в GitHub Secrets

Перейдите в настройки репозитория: **Settings → Secrets and variables → Actions → New repository secret**

Добавьте следующие секреты:

- `KUBE_SERVER` - URL сервера кластера
- `KUBE_CA_DATA` - CA сертификат (base64)
- `KUBE_BEARER_TOKEN` - токен Service Account

### 3. Готово!

GitHub Actions автоматически подключится к кластеру при следующем запуске workflow.

## Что делает скрипт

1. ✅ Проверяет зависимости (kubectl, yc, jq)
2. ✅ Проверяет подключение к кластеру
3. ✅ Применяет манифест Service Account
4. ✅ Получает все необходимые данные
5. ✅ Сохраняет данные в файл `github-secrets.txt`

## Требования

- kubectl настроен и подключен к кластеру
- yc CLI установлен и авторизован
- jq установлен
- Права администратора в кластере

## Устранение неполадок

### Ошибка "kubectl не найден"
```bash
# Установите kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Ошибка "yc не найден"
```bash
# Установите yc CLI
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

### Ошибка "jq не найден"
```bash
# Установите jq
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

### Ошибка подключения к кластеру
```bash
# Проверьте подключение
kubectl cluster-info

# Если нужно, подключитесь к кластеру
yc managed-kubernetes cluster get-credentials --id <CLUSTER_ID> --external
```