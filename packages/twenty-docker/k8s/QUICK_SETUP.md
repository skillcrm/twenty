# 🚀 Быстрая настройка статической конфигурации GitHub Actions

## Один скрипт - все готово!

### Шаг 1: Запустите скрипт

```bash
cd packages/twenty-docker/k8s
./get-github-secrets.sh
```

### Шаг 2: Скопируйте данные в GitHub

Перейдите в **Settings → Secrets and variables → Actions → New repository secret**

Добавьте эти секреты:

| Секрет | Значение |
|--------|----------|
| `KUBE_SERVER` | `https://130.193.35.57` |
| `KUBE_CA_DATA` | `LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...` |
| `KUBE_BEARER_TOKEN` | `eyJhbGciOiJSUzI1NiIsImtpZCI6ImZ4dmdx...` |

### Шаг 3: Готово! 🎉

GitHub Actions автоматически подключится к кластеру при следующем запуске.

## Что получили

✅ **KUBE_SERVER** - URL сервера кластера  
✅ **KUBE_CA_DATA** - CA сертификат (base64)  
✅ **KUBE_BEARER_TOKEN** - токен Service Account  
✅ **YC_CLOUD_ID** - ID облака (опционально)  
✅ **YC_FOLDER_ID** - ID папки (опционально)  

## Проверка

После добавления секретов, GitHub Actions будет:
1. Подключаться к кластеру используя статическую конфигурацию
2. Развертывать приложение в Kubernetes
3. Выполнять health check

## Устранение неполадок

### Скрипт не запускается
```bash
chmod +x get-github-secrets.sh
```

### Ошибка подключения к кластеру
```bash
kubectl cluster-info
yc managed-kubernetes cluster get-credentials --id <CLUSTER_ID> --external
```

### Ошибка в GitHub Actions
Проверьте, что все секреты добавлены правильно и без лишних пробелов.
