#!/bin/bash

# Полностью автоматический скрипт для получения данных GitHub Secrets
# для статической конфигурации Yandex Managed Kubernetes

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверяем наличие необходимых команд
check_dependencies() {
    print_status "Проверка зависимостей..."
    
    local missing_deps=()
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing_deps+=("kubectl")
    fi
    
    if ! command -v yc >/dev/null 2>&1; then
        missing_deps+=("yc")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые команды: ${missing_deps[*]}"
        print_error "Установите их и повторите попытку"
        exit 1
    fi
    
    print_success "Все зависимости установлены"
}

# Проверяем подключение к кластеру
check_cluster_connection() {
    print_status "Проверка подключения к кластеру..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Не удается подключиться к кластеру Kubernetes"
        print_error "Убедитесь, что kubectl настроен и кластер доступен"
        exit 1
    fi
    
    print_success "Подключение к кластеру успешно"
}

# Применяем манифест Service Account
apply_service_account() {
    print_status "Применение манифеста Service Account..."
    
    if ! kubectl apply -f ../sa.yaml >/dev/null 2>&1; then
        print_error "Не удалось применить манифест Service Account"
        exit 1
    fi
    
    print_success "Service Account создан"
    
    # Ждем создания токена
    print_status "Ожидание создания токена..."
    sleep 10
    
    # Проверяем, что токен создан
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get secret github-actions-sa-token -n kube-system >/dev/null 2>&1; then
            print_success "Токен создан"
            return 0
        fi
        
        print_status "Ожидание токена... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Токен не был создан в течение ожидаемого времени"
    exit 1
}

# Получаем все необходимые данные
get_github_secrets() {
    print_status "Получение данных для GitHub Secrets..."
    
    # Получаем сервер кластера
    local kube_server
    kube_server=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster.server')
    
    if [ "$kube_server" = "null" ] || [ -z "$kube_server" ]; then
        print_error "Не удалось получить сервер кластера"
        exit 1
    fi
    
    # Получаем CA сертификат
    local kube_ca_data
    kube_ca_data=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster."certificate-authority-data"')
    
    if [ "$kube_ca_data" = "null" ] || [ -z "$kube_ca_data" ]; then
        print_error "Не удалось получить CA сертификат"
        exit 1
    fi
    
    # Получаем токен
    local kube_bearer_token
    kube_bearer_token=$(kubectl get secret github-actions-sa-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
    
    if [ -z "$kube_bearer_token" ]; then
        print_error "Не удалось получить токен Service Account"
        exit 1
    fi
    
    # Получаем конфигурацию Yandex Cloud
    local yc_cloud_id
    local yc_folder_id
    local yc_sa_key_json
    
    yc_cloud_id=$(yc config get cloud-id 2>/dev/null || echo "")
    yc_folder_id=$(yc config get folder-id 2>/dev/null || echo "")
    
    if [ -f "sa-key.json" ]; then
        yc_sa_key_json=$(cat sa-key.json)
    else
        print_warning "Файл sa-key.json не найден, создаем новый..."
        yc_sa_key_json=$(yc iam key create --service-account-name github-actions-sa --format json 2>/dev/null || echo "")
    fi
    
    # Выводим результаты
    echo ""
    echo "=========================================="
    echo "🔑 GitHub Secrets для статической конфигурации"
    echo "=========================================="
    echo ""
    
    echo "KUBE_SERVER:"
    echo "$kube_server"
    echo ""
    
    echo "KUBE_CA_DATA:"
    echo "$kube_ca_data"
    echo ""
    
    echo "KUBE_BEARER_TOKEN:"
    echo "$kube_bearer_token"
    echo ""
    
    if [ -n "$yc_cloud_id" ]; then
        echo "YC_CLOUD_ID:"
        echo "$yc_cloud_id"
        echo ""
    fi
    
    if [ -n "$yc_folder_id" ]; then
        echo "YC_FOLDER_ID:"
        echo "$yc_folder_id"
        echo ""
    fi
    
    if [ -n "$yc_sa_key_json" ]; then
        echo "YC_SA_KEY_JSON:"
        echo "$yc_sa_key_json"
        echo ""
    fi
    
    echo "=========================================="
    echo "✅ Все данные получены успешно!"
    echo "=========================================="
    echo ""
    
    print_success "Скопируйте эти значения в GitHub Secrets:"
    print_success "Settings → Secrets and variables → Actions → New repository secret"
    echo ""
    
    # Сохраняем в файл для удобства
    local output_file="github-secrets.txt"
    cat > "$output_file" << EOF
# GitHub Secrets для статической конфигурации Yandex Managed Kubernetes
# Создано: $(date)

KUBE_SERVER=$kube_server

KUBE_CA_DATA=$kube_ca_data

KUBE_BEARER_TOKEN=$kube_bearer_token

YC_CLOUD_ID=$yc_cloud_id

YC_FOLDER_ID=$yc_folder_id

YC_SA_KEY_JSON=$yc_sa_key_json
EOF
    
    print_success "Данные также сохранены в файл: $output_file"
}

# Основная функция
main() {
    echo "🚀 Автоматическое получение данных для GitHub Secrets"
    echo "=================================================="
    echo ""
    
    check_dependencies
    check_cluster_connection
    apply_service_account
    get_github_secrets
    
    echo ""
    print_success "Готово! Теперь добавьте эти секреты в GitHub."
}

# Запуск
main "$@"
