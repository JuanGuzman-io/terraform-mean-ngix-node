# Makefile - Automatización de comandos Terraform
# Proyecto: MEAN Stack Deployment
# Equipo: TechOps Solutions

# Variables
TERRAFORM_VERSION := 1.5.0
AWS_REGION := us-east-1
PROJECT_NAME := mean-stack
ENVIRONMENT := dev

# Colores para output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help init plan apply destroy validate format check-aws clean logs

# Comando por defecto
.DEFAULT_GOAL := help

## Mostrar ayuda
help:
	@echo "${BLUE}=== MEAN Stack Terraform Deployment ===${NC}"
	@echo "${YELLOW}Comandos disponibles:${NC}"
	@echo ""
	@echo "  ${GREEN}setup${NC}       - Configuración inicial completa"
	@echo "  ${GREEN}init${NC}        - Inicializar Terraform"
	@echo "  ${GREEN}validate${NC}    - Validar configuración"
	@echo "  ${GREEN}format${NC}      - Formatear archivos .tf"
	@echo "  ${GREEN}plan${NC}        - Planificar cambios"
	@echo "  ${GREEN}apply${NC}       - Aplicar cambios"
	@echo "  ${GREEN}destroy${NC}     - Destruir infraestructura"
	@echo "  ${GREEN}check-aws${NC}   - Verificar configuración AWS"
	@echo "  ${GREEN}logs${NC}        - Ver logs de CloudWatch"
	@echo "  ${GREEN}test${NC}        - Probar aplicación desplegada"
	@echo "  ${GREEN}clean${NC}       - Limpiar archivos temporales"
	@echo ""

## Configuración inicial completa
setup: check-aws check-terraform create-keypair init validate
	@echo "${GREEN}✅ Configuración inicial completada${NC}"

## Verificar que AWS CLI está configurado
check-aws:
	@echo "${BLUE}🔍 Verificando configuración de AWS...${NC}"
	@aws sts get-caller-identity > /dev/null || (echo "${RED}❌ AWS CLI no configurado${NC}" && exit 1)
	@echo "${GREEN}✅ AWS CLI configurado correctamente${NC}"

## Verificar que Terraform está instalado
check-terraform:
	@echo "${BLUE}🔍 Verificando Terraform...${NC}"
	@terraform version > /dev/null || (echo "${RED}❌ Terraform no instalado${NC}" && exit 1)
	@echo "${GREEN}✅ Terraform instalado${NC}"

## Crear par de claves EC2 si no existe
create-keypair:
	@echo "${BLUE}🔑 Verificando par de claves EC2...${NC}"
	@if ! aws ec2 describe-key-pairs --key-names $(PROJECT_NAME)-keypair >/dev/null 2>&1; then \
		echo "${YELLOW}⚠️  Creando par de claves EC2...${NC}"; \
		aws ec2 create-key-pair --key-name $(PROJECT_NAME)-keypair \
			--query 'KeyMaterial' --output text > $(PROJECT_NAME)-keypair.pem; \
		chmod 400 $(PROJECT_NAME)-keypair.pem; \
		echo "${GREEN}✅ Par de claves creado: $(PROJECT_NAME)-keypair.pem${NC}"; \
	else \
		echo "${GREEN}✅ Par de claves ya existe${NC}"; \
	fi

## Inicializar Terraform
init:
	@echo "${BLUE}🚀 Inicializando Terraform...${NC}"
	@terraform init -upgrade
	@echo "${GREEN}✅ Terraform inicializado${NC}"

## Validar configuración
validate:
	@echo "${BLUE}✅ Validando configuración...${NC}"
	@terraform validate
	@echo "${GREEN}✅ Configuración válida${NC}"

## Formatear archivos Terraform
format:
	@echo "${BLUE}🎨 Formateando archivos .tf...${NC}"
	@terraform fmt -recursive
	@echo "${GREEN}✅ Archivos formateados${NC}"

## Planificar cambios
plan:
	@echo "${BLUE}📋 Planificando cambios...${NC}"
	@terraform plan -out=tfplan
	@echo "${GREEN}✅ Plan generado: tfplan${NC}"

## Aplicar cambios con confirmación
apply:
	@echo "${YELLOW}⚠️  ¿Estás seguro de aplicar los cambios? [y/N]${NC}"
	@read -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "${BLUE}🚀 Aplicando cambios...${NC}"; \
		terraform apply tfplan; \
		echo "${GREEN}✅ Cambios aplicados exitosamente${NC}"; \
		$(MAKE) show-outputs; \
	else \
		echo ""; \
		echo "${YELLOW}⏸️  Aplicación cancelada${NC}"; \
	fi

## Aplicar cambios sin confirmación (para CI/CD)
apply-auto:
	@echo "${BLUE}🚀 Aplicando cambios automáticamente...${NC}"
	@terraform apply -auto-approve
	@echo "${GREEN}✅ Cambios aplicados exitosamente${NC}"
	@$(MAKE) show-outputs

## Mostrar outputs importantes
show-outputs:
	@echo "${BLUE}📊 Información del despliegue:${NC}"
	@echo ""
	@echo "${GREEN}🌐 URL de la aplicación:${NC}"
	@terraform output application_url
	@echo ""
	@echo "${GREEN}🏠 IPs privadas:${NC}"
	@echo "  Servidor Web: $$(terraform output -raw web_instance_private_ip)"
	@echo "  MongoDB: $$(terraform output -raw db_instance_private_ip)"
	@echo ""
	@echo "${GREEN}🌍 DNS del Load Balancer:${NC}"
	@terraform output alb_dns_name
	@echo ""
	@echo "${GREEN}📍 IP del NAT Gateway:${NC}"
	@terraform output nat_gateway_public_ip

## Destruir infraestructura con confirmación
destroy:
	@echo "${RED}⚠️  ¿ESTÁS SEGURO de destruir toda la infraestructura? [y/N]${NC}"
	@read -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "${RED}💥 Destruyendo infraestructura...${NC}"; \
		terraform destroy -auto-approve; \
		echo "${GREEN}✅ Infraestructura destruida${NC}"; \
	else \
		echo ""; \
		echo "${YELLOW}⏸️  Destrucción cancelada${NC}"; \
	fi

## Probar la aplicación desplegada
test:
	@echo "${BLUE}🧪 Probando aplicación...${NC}"
	@APP_URL=$$(terraform output -raw application_url 2>/dev/null); \
	if [ -n "$$APP_URL" ]; then \
		echo "Probando: $$APP_URL/api/health"; \
		curl -f "$$APP_URL/api/health" && echo "${GREEN}✅ Aplicación funcionando${NC}" || echo "${RED}❌ Aplicación no responde${NC}"; \
	else \
		echo "${RED}❌ No se pudo obtener la URL de la aplicación${NC}"; \
	fi

## Ver logs de CloudWatch
logs:
	@echo "${BLUE}📝 Obteniendo logs recientes...${NC}"
	@echo "Logs del servidor web:"
	@aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/$(PROJECT_NAME)-$(ENVIRONMENT)-web" || echo "No se encontraron logs del servidor web"
	@echo ""
	@echo "Logs de MongoDB:"
	@aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/$(PROJECT_NAME)-$(ENVIRONMENT)-db" || echo "No se encontraron logs de MongoDB"

## Limpiar archivos temporales
clean:
	@echo "${BLUE}🧹 Limpiando archivos temporales...${NC}"
	@rm -f tfplan
	@rm -f terraform.tfstate.backup
	@rm -rf .terraform/providers
	@echo "${GREEN}✅ Archivos temporales eliminados${NC}"

## Mostrar estado actual
status:
	@echo "${BLUE}📊 Estado de la infraestructura:${NC}"
	@terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_instance") | "\(.values.tags.Name): \(.values.instance_state)"' 2>/dev/null || echo "No hay instancias desplegadas"

## Refrescar estado
refresh:
	@echo "${BLUE}🔄 Refrescando estado...${NC}"
	@terraform refresh
	@echo "${GREEN}✅ Estado refrescado${NC}"

## Actualizar módulos
update:
	@echo "${BLUE}⬆️  Actualizando módulos...${NC}"
	@terraform get -update
	@terraform init -upgrade
	@echo "${GREEN}✅ Módulos actualizados${NC}"
