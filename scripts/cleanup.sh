#!/bin/bash
# Script de limpieza completa del proyecto

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  LIMPIEZA COMPLETA DEL PROYECTO MEAN  ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Función para confirmar acciones
confirm() {
    read -p "¿Estás seguro de que quieres $1? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 1. Destruir infraestructura de Terraform
echo -e "${YELLOW}🏗️  Verificando infraestructura de Terraform...${NC}"
if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
    echo -e "${YELLOW}Se encontró infraestructura de Terraform desplegada.${NC}"
    if confirm "destruir toda la infraestructura de AWS"; then
        echo -e "${RED}💥 Destruyendo infraestructura...${NC}"
        terraform destroy -auto-approve
        echo -e "${GREEN}✅ Infraestructura destruida${NC}"
    else
        echo -e "${YELLOW}⏸️  Destrucción de infraestructura cancelada${NC}"
    fi
else
    echo -e "${GREEN}✅ No se encontró infraestructura desplegada${NC}"
fi

echo ""

# 2. Limpiar archivos de Terraform
echo -e "${YELLOW}🧹 Limpiando archivos de Terraform...${NC}"
files_to_remove=(
    "terraform.tfstate"
    "terraform.tfstate.backup"
    "tfplan"
    ".terraform/"
    ".terraform.lock.hcl"
    "crash.log"
)

for file in "${files_to_remove[@]}"; do
    if [ -e "$file" ]; then
        rm -rf "$file"
        echo -e "${GREEN}✅ Eliminado: $file${NC}"
    fi
done

# 3. Limpiar archivos de credenciales
echo ""
echo -e "${YELLOW}🔑 Verificando archivos de credenciales...${NC}"
credential_files=(
    "*.pem"
    "*.key"
    "terraform.tfvars"
    ".env"
    "*.env"
)

for pattern in "${credential_files[@]}"; do
    if ls $pattern 1>/dev/null 2>&1; then
        if confirm "eliminar archivos de credenciales ($pattern)"; then
            rm -f $pattern
            echo -e "${GREEN}✅ Eliminados archivos: $pattern${NC}"
        fi
    fi
done

# 4. Limpiar logs
echo ""
echo -e "${YELLOW}📝 Limpiando logs...${NC}"
log_files=(
    "*.log"
    "logs/"
    "/tmp/validation-*.log"
)

for pattern in "${log_files[@]}"; do
    if ls $pattern 1>/dev/null 2>&1; then
        rm -rf $pattern
        echo -e "${GREEN}✅ Eliminados logs: $pattern${NC}"
    fi
done

# 5. Limpiar archivos temporales
echo ""
echo -e "${YELLOW}🗑️  Limpiando archivos temporales...${NC}"
temp_files=(
    "tmp/"
    "temp/"
    "*.tmp"
    "*.backup"
    "*.bak"
)

for pattern in "${temp_files[@]}"; do
    if ls $pattern 1>/dev/null 2>&1; then
        rm -rf $pattern
        echo -e "${GREEN}✅ Eliminados temporales: $pattern${NC}"
    fi
done

# 6. Limpiar contenedores Docker (si existen)
echo ""
echo -e "${YELLOW}🐳 Verificando contenedores Docker...${NC}"
if command -v docker &>/dev/null; then
    if [ "$(docker ps -q -f name=mean)" ]; then
        if confirm "detener y eliminar contenedores Docker del proyecto"; then
            docker-compose down -v
            docker system prune -f
            echo -e "${GREEN}✅ Contenedores Docker eliminados${NC}"
        fi
    else
        echo -e "${GREEN}✅ No se encontraron contenedores Docker${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  Docker no está instalado${NC}"
fi

# 7. Verificar recursos en AWS
echo ""
echo -e "${YELLOW}☁️  Verificando recursos restantes en AWS...${NC}"
if command -v aws &>/dev/null; then
    echo -e "${BLUE}Verificando instancias EC2...${NC}"
    instances=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=mean-stack" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")

    if [ -n "$instances" ]; then
        echo -e "${RED}⚠️  Se encontraron instancias EC2 activas: $instances${NC}"
        echo -e "${YELLOW}Considera terminarlas manualmente desde la consola AWS${NC}"
    else
        echo -e "${GREEN}✅ No se encontraron instancias EC2 activas${NC}"
    fi

    echo -e "${BLUE}Verificando Load Balancers...${NC}"
    albs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `mean-stack`)].LoadBalancerArn' --output text 2>/dev/null || echo "")

    if [ -n "$albs" ]; then
        echo -e "${RED}⚠️  Se encontraron Load Balancers activos${NC}"
        echo -e "${YELLOW}Considera eliminarlos manualmente desde la consola AWS${NC}"
    else
        echo -e "${GREEN}✅ No se encontraron Load Balancers activos${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  AWS CLI no está configurado, no se puede verificar recursos${NC}"
fi

# 8. Resumen final
echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}        RESUMEN DE LIMPIEZA             ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo -e "${GREEN}✅ Limpieza completada exitosamente${NC}"
echo ""
echo -e "${BLUE}Archivos preservados:${NC}"
echo -e "${YELLOW}  - Código fuente (.tf, .sh, .md)${NC}"
echo -e "${YELLOW}  - Configuración del proyecto${NC}"
echo -e "${YELLOW}  - Documentación${NC}"
echo ""
echo -e "${BLUE}Para reiniciar el proyecto:${NC}"
echo -e "${YELLOW}  1. Configurar terraform.tfvars${NC}"
echo -e "${YELLOW}  2. Ejecutar: make setup${NC}"
echo -e "${YELLOW}  3. Ejecutar: make apply${NC}"
echo ""
echo -e "${GREEN}🎉 Proyecto limpio y listo para nuevo despliegue${NC}"
