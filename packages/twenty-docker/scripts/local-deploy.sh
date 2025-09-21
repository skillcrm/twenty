#!/bin/bash

# Локальный деплой в Kubernetes
# Использование: ./local-deploy.sh [stage|prod] [tag]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    print_status "Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl не установлен"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq не установлен, некоторые проверки будут пропущены"
    fi
    
    print_success "Все зависимости установлены"
}

# Проверка подключения к кластеру
check_kubectl_connection() {
    print_status "Проверка подключения к Kubernetes кластеру..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру"
        print_error "Убедитесь, что kubectl настроен и кластер доступен"
        exit 1
    fi
    
    local cluster_info=$(kubectl cluster-info --request-timeout=5s 2>/dev/null | head -n 1)
    print_success "Подключен к кластеру: $cluster_info"
}

# Проверка Docker Registry
check_docker_registry() {
    print_status "Проверка подключения к Docker Registry..."
    
    if ! docker info &> /dev/null; then
        print_error "Docker не запущен"
        exit 1
    fi
    
    print_success "Docker доступен"
}

# Сборка и загрузка образов
build_and_push() {
    local environment=$1
    local tag=$2
    local registry="skillcrm-register.registry.twcstorage.ru"
    local image_name="twenty"
    local full_image="$registry/$image_name:$tag"
    
    print_status "Сборка и загрузка образа: $full_image"
    
    # Сборка образа
    print_status "Сборка Docker образа..."
    if ! docker build -t "$full_image" -f twenty/Dockerfile .; then
        print_error "Ошибка сборки образа"
        exit 1
    fi
    
    # Загрузка в registry
    print_status "Загрузка образа в registry..."
    if ! docker push "$full_image"; then
        print_error "Ошибка загрузки образа"
        exit 1
    fi
    
    print_success "Образ успешно загружен: $full_image"
}

# Обновление образа в deployment
update_deployment() {
    local environment=$1
    local tag=$2
    local namespace="twentycrm${environment:+-$environment}"
    local deployment_name="twentycrm${environment:+-$environment}-server"
    local registry="skillcrm-register.registry.twcstorage.ru"
    local image_name="twenty"
    local full_image="$registry/$image_name:$tag"
    
    print_status "Обновление deployment: $deployment_name в namespace: $namespace"
    
    # Проверка существования namespace
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_error "Namespace $namespace не существует"
        print_error "Создайте namespace: kubectl create namespace $namespace"
        exit 1
    fi
    
    # Проверка существования deployment
    if ! kubectl get deployment "$deployment_name" -n "$namespace" &> /dev/null; then
        print_error "Deployment $deployment_name не существует в namespace $namespace"
        print_error "Сначала примените манифесты: kubectl apply -f k8s/"
        exit 1
    fi
    
    # Обновление образа
    print_status "Обновление образа в deployment..."
    if ! kubectl set image deployment/"$deployment_name" server="$full_image" -n "$namespace"; then
        print_error "Ошибка обновления образа"
        exit 1
    fi
    
    print_success "Образ обновлен в deployment"
}

# Ожидание готовности deployment
wait_for_deployment() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    local deployment_name="twentycrm${environment:+-$environment}-server"
    
    print_status "Ожидание готовности deployment..."
    
    if ! kubectl rollout status deployment/"$deployment_name" -n "$namespace" --timeout=300s; then
        print_error "Deployment не готов в течение 5 минут"
        print_error "Проверьте логи: kubectl logs -l app=twentycrm -n $namespace"
        exit 1
    fi
    
    print_success "Deployment готов"
}

# Проверка здоровья приложения
health_check() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    local service_name="twentycrm${environment:+-$environment}-server"
    
    print_status "Проверка здоровья приложения..."
    
    # Получение URL сервиса
    local service_port=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}')
    
    # Проброс порта для проверки
    print_status "Запуск проброса порта для проверки..."
    kubectl port-forward service/"$service_name" 8080:"$service_port" -n "$namespace" &
    local port_forward_pid=$!
    
    # Ожидание готовности проброса
    sleep 5
    
    # Проверка здоровья
    local health_url="http://localhost:8080/health"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$health_url" > /dev/null 2>&1; then
            print_success "Приложение здорово"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Приложение не отвечает на проверку здоровья"
            kill $port_forward_pid 2>/dev/null || true
            exit 1
        fi
        
        print_status "Попытка $attempt/$max_attempts - ожидание..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    # Остановка проброса порта
    kill $port_forward_pid 2>/dev/null || true
}

# Показать статус
show_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус deployment:"
    kubectl get pods -l app=twentycrm -n "$namespace"
    
    print_status "Статус сервисов:"
    kubectl get services -n "$namespace"
    
    print_status "Статус ingress:"
    kubectl get ingress -n "$namespace"
}

# Основная функция
main() {
    local environment=${1:-stage}
    local tag=${2:-latest}
    
    # Валидация параметров
    if [[ "$environment" != "stage" && "$environment" != "prod" ]]; then
        print_error "Недопустимая среда: $environment"
        print_error "Используйте: stage или prod"
        exit 1
    fi
    
    print_status "Начинаем локальный деплой в $environment с тегом $tag"
    
    # Проверки
    check_dependencies
    check_kubectl_connection
    check_docker_registry
    
    # Сборка и загрузка
    build_and_push "$environment" "$tag"
    
    # Обновление deployment
    update_deployment "$environment" "$tag"
    
    # Ожидание готовности
    wait_for_deployment "$environment"
    
    # Проверка здоровья
    health_check "$environment"
    
    # Показать статус
    show_status "$environment"
    
    print_success "Деплой завершен успешно!"
    print_status "Приложение доступно в namespace: twentycrm${environment:+-$environment}"
}

# Обработка сигналов
trap 'print_error "Прервано пользователем"; exit 1' INT TERM

# Запуск
main "$@"
