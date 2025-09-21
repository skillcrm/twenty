#!/bin/bash

# Проверка статуса развертывания в Kubernetes
# Использование: ./status.sh [stage|prod]

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

# Проверка подключения к кластеру
check_kubectl_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру"
        exit 1
    fi
}

# Показать статус namespace
show_namespace_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус namespace: $namespace"
    echo "----------------------------------------"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_error "Namespace $namespace не существует"
        return 1
    fi
    
    # Информация о namespace
    kubectl get namespace "$namespace" -o wide
    echo ""
}

# Показать статус pods
show_pods_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус Pods в namespace: $namespace"
    echo "----------------------------------------"
    
    if ! kubectl get pods -n "$namespace" &> /dev/null; then
        print_error "Не удается получить информацию о pods"
        return 1
    fi
    
    kubectl get pods -n "$namespace" -o wide
    echo ""
    
    # Детальная информация о каждом pod
    local pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
    for pod in $pods; do
        print_status "Детали Pod: $pod"
        echo "----------------------------------------"
        kubectl describe pod "$pod" -n "$namespace" | grep -A 10 "Status:"
        echo ""
    done
}

# Показать статус deployments
show_deployments_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус Deployments в namespace: $namespace"
    echo "----------------------------------------"
    
    kubectl get deployments -n "$namespace" -o wide
    echo ""
    
    # Детальная информация о каждом deployment
    local deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
    for deployment in $deployments; do
        print_status "Детали Deployment: $deployment"
        echo "----------------------------------------"
        kubectl describe deployment "$deployment" -n "$namespace" | grep -A 5 "Image:"
        echo ""
    done
}

# Показать статус services
show_services_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус Services в namespace: $namespace"
    echo "----------------------------------------"
    
    kubectl get services -n "$namespace" -o wide
    echo ""
}

# Показать статус ingress
show_ingress_status() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус Ingress в namespace: $namespace"
    echo "----------------------------------------"
    
    kubectl get ingress -n "$namespace" -o wide
    echo ""
}

# Показать логи
show_logs() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    local lines=${2:-50}
    
    print_status "Последние $lines строк логов в namespace: $namespace"
    echo "----------------------------------------"
    
    local pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
    for pod in $pods; do
        print_status "Логи Pod: $pod"
        echo "----------------------------------------"
        kubectl logs "$pod" -n "$namespace" --tail="$lines" || true
        echo ""
    done
}

# Проверка здоровья приложения
check_health() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    local service_name="twentycrm${environment:+-$environment}-server"
    
    print_status "Проверка здоровья приложения в namespace: $namespace"
    echo "----------------------------------------"
    
    # Проверка, что сервис существует
    if ! kubectl get service "$service_name" -n "$namespace" &> /dev/null; then
        print_error "Сервис $service_name не существует"
        return 1
    fi
    
    # Получение порта сервиса
    local service_port=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}')
    
    # Проброс порта для проверки
    print_status "Запуск проброса порта для проверки здоровья..."
    kubectl port-forward service/"$service_name" 8080:"$service_port" -n "$namespace" &
    local port_forward_pid=$!
    
    # Ожидание готовности проброса
    sleep 3
    
    # Проверка здоровья
    local health_url="http://localhost:8080/health"
    if curl -s -f "$health_url" > /dev/null 2>&1; then
        print_success "Приложение здорово"
    else
        print_error "Приложение не отвечает на проверку здоровья"
    fi
    
    # Остановка проброса порта
    kill $port_forward_pid 2>/dev/null || true
    echo ""
}

# Показать ресурсы
show_resources() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Использование ресурсов в namespace: $namespace"
    echo "----------------------------------------"
    
    # CPU и память по pods
    kubectl top pods -n "$namespace" 2>/dev/null || print_warning "Метрики недоступны (установите metrics-server)"
    echo ""
    
    # CPU и память по nodes
    kubectl top nodes 2>/dev/null || print_warning "Метрики узлов недоступны"
    echo ""
}

# Показать события
show_events() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "События в namespace: $namespace"
    echo "----------------------------------------"
    
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | tail -20
    echo ""
}

# Основная функция
main() {
    local environment=${1:-stage}
    local show_logs_flag=$2
    
    # Валидация параметров
    if [[ "$environment" != "stage" && "$environment" != "prod" ]]; then
        print_error "Недопустимая среда: $environment"
        print_error "Используйте: stage или prod"
        exit 1
    fi
    
    print_status "Проверка статуса развертывания в $environment"
    echo "========================================"
    
    # Проверка подключения
    check_kubectl_connection
    
    # Показать статус
    show_namespace_status "$environment"
    show_pods_status "$environment"
    show_deployments_status "$environment"
    show_services_status "$environment"
    show_ingress_status "$environment"
    
    # Проверка здоровья
    check_health "$environment"
    
    # Показать ресурсы
    show_resources "$environment"
    
    # Показать события
    show_events "$environment"
    
    # Показать логи, если запрошено
    if [[ "$show_logs_flag" == "--logs" ]]; then
        show_logs "$environment"
    fi
    
    print_success "Проверка статуса завершена"
}

# Показать помощь
show_help() {
    echo "Проверка статуса развертывания в Kubernetes"
    echo ""
    echo "Использование:"
    echo "  $0 [stage|prod] [--logs]"
    echo ""
    echo "Параметры:"
    echo "  stage    Проверить stage среду (по умолчанию)"
    echo "  prod     Проверить production среду"
    echo "  --logs   Показать логи приложений"
    echo ""
    echo "Примеры:"
    echo "  $0 stage           # Проверить статус stage"
    echo "  $0 prod --logs     # Проверить статус prod с логами"
}

# Обработка параметров
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Запуск
main "$@"
