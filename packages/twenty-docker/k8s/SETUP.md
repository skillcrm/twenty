# Настройка подключения к Yandex Managed Kubernetes

Этот документ описывает процесс настройки подключения GitHub Actions к кластеру Yandex Managed Kubernetes.

## Предварительные требования

1. Установленный `kubectl`
2. Установленный `yc` CLI
3. Доступ к кластеру Yandex Managed Kubernetes
4. Права администратора в GitHub репозитории

## Метод 1: Статическая конфигурация (Рекомендуется)

### Шаг 1: Создание Service Account в Yandex Cloud

```bash
# Создаем Service Account
yc iam service-account create --name github-actions-sa --description "Service Account for GitHub Actions"

# Получаем ID Service Account
SA_ID=$(yc iam service-account get github-actions-sa --format json | jq -r '.id')

# Создаем ключ для Service Account
yc iam key create --service-account-name github-actions-sa --output sa-key.json
```

### Шаг 2: Настройка прав доступа

```bash
# Назначаем роль editor для папки
yc resource-manager folder add-access-binding --id <FOLDER_ID> --role editor --subject serviceAccount:$SA_ID

# Назначаем роль k8s.clusters.agent для кластера
yc managed-kubernetes cluster add-access-binding --id <CLUSTER_ID> --role k8s.clusters.agent --subject serviceAccount:$SA_ID
```

### Шаг 3: Получение токена для кластера

```bash
# Подключаемся к кластеру
yc managed-kubernetes cluster get-credentials --id <CLUSTER_ID> --external

# Применяем манифест Service Account
kubectl apply -f ../sa.yaml

# Получаем токен
./get-token.sh
```

### Шаг 4: Получение конфигурации кластера

```bash
# Получаем сервер кластера
kubectl config view --raw -o json | jq -r '.clusters[0].cluster.server'

# Получаем CA сертификат
kubectl config view --raw -o json | jq -r '.clusters[0].cluster.certificate-authority-data'
```

### Шаг 5: Настройка GitHub Secrets

В настройках репозитория GitHub (Settings → Secrets and variables → Actions) добавьте:

- `KUBE_SERVER` - URL сервера кластера
- `KUBE_CA_DATA` - CA сертификат (base64)
- `KUBE_BEARER_TOKEN` - токен Service Account
- `YC_SA_KEY_JSON` - содержимое файла sa-key.json
- `YC_CLOUD_ID` - ID облака
- `YC_FOLDER_ID` - ID папки

## Метод 2: Полная конфигурация kubeconfig

### Шаг 1: Получение kubeconfig

```bash
# Получаем kubeconfig
yc managed-kubernetes cluster get-credentials --id <CLUSTER_ID> --external

# Кодируем в base64
cat ~/.kube/config | base64 -w 0
```

### Шаг 2: Настройка GitHub Secrets

Добавьте в GitHub Secrets:
- `KUBECONFIG` - base64 закодированный kubeconfig

## Проверка подключения

После настройки секретов, GitHub Actions автоматически подключится к кластеру при выполнении workflow.

Для локальной проверки:

```bash
# Проверяем подключение
kubectl cluster-info

# Проверяем права доступа
kubectl auth can-i '*' '*' --all-namespaces
```

## Устранение неполадок

### Ошибка "Unauthorized"

1. Проверьте правильность токена
2. Убедитесь, что Service Account имеет необходимые права
3. Проверьте срок действия токена

### Ошибка "Certificate verify failed"

1. Проверьте правильность CA сертификата
2. Убедитесь, что сертификат в формате base64

### Ошибка "Connection refused"

1. Проверьте правильность URL сервера
2. Убедитесь, что кластер доступен из интернета

## Безопасность

- Регулярно обновляйте токены Service Account
- Используйте минимально необходимые права доступа
- Не храните секреты в коде
- Используйте GitHub Environments для дополнительной защиты

## Полезные команды

```bash
# Просмотр текущей конфигурации
kubectl config view

# Переключение контекста
kubectl config use-context <context-name>

# Просмотр токенов
kubectl get secrets -n kube-system | grep token

# Проверка прав доступа
kubectl auth can-i <verb> <resource> --namespace <namespace>
```
