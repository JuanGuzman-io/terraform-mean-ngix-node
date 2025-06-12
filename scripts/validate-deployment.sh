#!/bin/bash

# Script de validación para el despliegue MEAN Stack
# Proyecto: TechOps Solutions - FinTech Solutions S.A.

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
LOG_FILE="/tmp/validation-$(date +%Y%m%d_%H%M%S).log"
TESTS_PASSED=0
TESTS_FAILED=0

# Función de logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Función para ejecutar test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"

    log "${BLUE}🧪 Ejecutando: $test_name${NC}"

    if eval "$test_command" >/dev/null 2>&1; then
        log "${GREEN}✅ PASSED: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        log "${RED}❌ FAILED: $test_name${NC}"
        log "${YELLOW}   Comando: $test_command${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Función para test con output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"

    log "${BLUE}🧪 Ejecutando: $test_name${NC}"

    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log "${GREEN}✅ PASSED: $test_name${NC}"
        log "${YELLOW}   Output: $output${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        log "${RED}❌ FAILED: $test_name${NC}"
        log "${YELLOW}   Error: $output${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

log "${BLUE}=======================================${NC}"
log "${BLUE}  VALIDACIÓN DE DESPLIEGUE MEAN STACK  ${NC}"
log "${BLUE}=======================================${NC}"
log ""

# Verificar que Terraform está instalado y configurado
log "${BLUE}📋 VERIFICANDO PREREQUISITOS${NC}"
run_test "Terraform instalado" "terraform version"
run_test "AWS CLI configurado" "aws sts get-caller-identity"
run_test "Directorio de trabajo correcto" "test -f main.tf"

log ""

# Verificar estado de Terraform
log "${BLUE}🏗️  VERIFICANDO ESTADO DE TERRAFORM${NC}"
run_test "Terraform inicializado" "test -d .terraform"
run_test "Estado de Terraform existe" "terraform show"
run_test "Configuración válida" "terraform validate"

log ""

# Obtener outputs de Terraform
log "${BLUE}📊 OBTENIENDO INFORMACIÓN DEL DESPLIEGUE${NC}"

ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
WEB_PRIVATE_IP=$(terraform output -raw web_instance_private_ip 2>/dev/null || echo "")
DB_PRIVATE_IP=$(terraform output -raw db_instance_private_ip 2>/dev/null || echo "")
NAT_PUBLIC_IP=$(terraform output -raw nat_gateway_public_ip 2>/dev/null || echo "")
APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "")

if [ -n "$ALB_DNS" ]; then
    log "${GREEN}✅ Load Balancer DNS: $ALB_DNS${NC}"
else
    log "${RED}❌ No se pudo obtener DNS del Load Balancer${NC}"
fi

if [ -n "$WEB_PRIVATE_IP" ]; then
    log "${GREEN}✅ IP privada servidor web: $WEB_PRIVATE_IP${NC}"
else
    log "${RED}❌ No se pudo obtener IP del servidor web${NC}"
fi

if [ -n "$DB_PRIVATE_IP" ]; then
    log "${GREEN}✅ IP privada MongoDB: $DB_PRIVATE_IP${NC}"
else
    log "${RED}❌ No se pudo obtener IP de MongoDB${NC}"
fi

log ""

# Verificar recursos de AWS
log "${BLUE}☁️  VERIFICANDO RECURSOS EN AWS${NC}"

# Verificar VPC
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [ -n "$VPC_ID" ]; then
    run_test "VPC existe" "aws ec2 describe-vpcs --vpc-ids $VPC_ID"
fi

# Verificar instancias EC2
run_test "Instancias EC2 ejecutándose" "aws ec2 describe-instances --filters 'Name=tag:Project,Values=mean-stack' 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].InstanceId' --output text | grep -q i-"

# Verificar Load Balancer
if [ -n "$ALB_DNS" ]; then
    ALB_NAME=$(echo "$ALB_DNS" | cut -d'-' -f1-3)
    run_test "Load Balancer activo" "aws elbv2 describe-load-balancers --names $ALB_NAME"
fi

# Verificar NAT Gateway
run_test "NAT Gateway activo" "aws ec2 describe-nat-gateways --filter 'Name=tag:Project,Values=mean-stack' 'Name=state,Values=available'"

log ""

# Verificar conectividad
log "${BLUE}🌐 VERIFICANDO CONECTIVIDAD${NC}"

if [ -n "$APP_URL" ]; then
    # Test de conectividad HTTP
    run_test "Conectividad HTTP al Load Balancer" "curl -f --max-time 30 '$APP_URL' -o /dev/null"

    # Test del endpoint de health check
    run_test "Health check de la API" "curl -f --max-time 30 '$APP_URL/api/health' | jq -e '.status == \"OK\"'"

    # Test de la página principal
    run_test "Página principal accesible" "curl -f --max-time 30 '$APP_URL' | grep -q 'MEAN Stack'"

    # Test de endpoint de la API
    run_test_with_output "Test API de items" "curl -f --max-time 30 '$APP_URL/api/items'"
else
    log "${YELLOW}⚠️  No se puede probar conectividad - URL no disponible${NC}"
fi

log ""

# Verificar logs en CloudWatch (si están disponibles)
log "${BLUE}📝 VERIFICANDO LOGS${NC}"

WEB_LOG_GROUP="/aws/ec2/mean-stack-dev-web-server"
DB_LOG_GROUP="/aws/ec2/mean-stack-dev-db-server"

run_test "Log group del servidor web existe" "aws logs describe-log-groups --log-group-name-prefix '$WEB_LOG_GROUP'"
run_test "Log group de MongoDB existe" "aws logs describe-log-groups --log-group-name-prefix '$DB_LOG_GROUP'"

log ""

# Verificar security groups
log "${BLUE}🔒 VERIFICANDO SECURITY GROUPS${NC}"

run_test "Security Groups configurados" "aws ec2 describe-security-groups --filters 'Name=tag:Project,Values=mean-stack' --query 'SecurityGroups[*].GroupId' --output text | grep -q sg-"

log ""

# Resumen final
log "${BLUE}=======================================${NC}"
log "${BLUE}           RESUMEN DE VALIDACIÓN        ${NC}"
log "${BLUE}=======================================${NC}"
log ""
log "${GREEN}✅ Tests exitosos: $TESTS_PASSED${NC}"
log "${RED}❌ Tests fallidos: $TESTS_FAILED${NC}"
log "${BLUE}📁 Log completo: $LOG_FILE${NC}"
log ""

if [ $TESTS_FAILED -eq 0 ]; then
    log "${GREEN}🎉 VALIDACIÓN COMPLETADA EXITOSAMENTE${NC}"
    log "${GREEN}✅ El despliegue MEAN Stack está funcionando correctamente${NC}"

    if [ -n "$APP_URL" ]; then
        log ""
        log "${BLUE}🌐 Acceder a la aplicación:${NC}"
        log "${YELLOW}   URL: $APP_URL${NC}"
        log "${YELLOW}   Health Check: $APP_URL/api/health${NC}"
        log "${YELLOW}   API Items: $APP_URL/api/items${NC}"
    fi

    exit 0
else
    log "${RED}💥 VALIDACIÓN FALLÓ${NC}"
    log "${RED}❌ Se encontraron $TESTS_FAILED problemas en el despliegue${NC}"
    log "${YELLOW}💡 Revisar el log completo en: $LOG_FILE${NC}"
    exit 1
fi
