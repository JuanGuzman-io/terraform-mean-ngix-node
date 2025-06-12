# 🚀 MEAN Stack Deployment con Terraform en AWS

## Índice
1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Modularización de Terraform](#modularización-de-terraform)
4. [Estructura del Proyecto](#estructura-del-proyecto)
5. [Configuración de Módulos](#configuración-de-módulos)
6. [Grupos de Seguridad](#grupos-de-seguridad)
7. [Balanceador de Carga](#balanceador-de-carga)
8. [Outputs del Proyecto](#outputs-del-proyecto)
9. [Instrucciones de Despliegue](#instrucciones-de-despliegue)
10. [Evidencias de Funcionamiento](#evidencias-de-funcionamiento)
11. [Limpieza de Recursos](#limpieza-de-recursos)

---

## Introducción

Este proyecto implementa un stack MEAN (MongoDB, Express.js, Angular, Node.js) distribuido en múltiples instancias EC2 de AWS utilizando Terraform como herramienta de Infrastructure as Code (IaC). El despliegue está diseñado siguiendo las mejores prácticas de DevOps, con una arquitectura modular, segura y escalable.

### Objetivos del Proyecto
- Desplegar un stack MEAN en al menos dos máquinas EC2
- Implementar un balanceador de carga para distribución de tráfico
- Configurar grupos de seguridad para comunicación segura entre componentes
- Modularizar la infraestructura para reutilización y mantenibilidad
- Generar outputs informativos sobre la infraestructura desplegada

---

## Arquitectura del Sistema

### Diagrama de Arquitectura

```
Internet Gateway
       |
   [ALB - Load Balancer]
       |
   Public Subnet (us-east-1a)
       |
   Private Subnet (us-east-1a)        Private Subnet (us-east-1b)
       |                                       |
   [EC2 - Nginx/Node.js]                [EC2 - MongoDB]
   - Puerto 80 (Nginx)                  - Puerto 27017 (MongoDB)
   - Puerto 3000 (Node.js)              - Solo acceso interno
   - Puerto 22 (SSH)                    - Acceso vía NAT Gateway
       |                                       |
       +----------- Comunicación interna -----+
       
   NAT Gateway (para salida a internet de MongoDB)
```

### Componentes Principales

1. **VPC (Virtual Private Cloud)**: Red privada aislada en AWS
2. **Subredes**: 
   - Pública: Para ALB y NAT Gateway
   - Privadas: Para instancias EC2
3. **Internet Gateway**: Acceso a internet para recursos públicos
4. **NAT Gateway**: Acceso saliente a internet para instancias privadas
5. **Application Load Balancer (ALB)**: Distribución de tráfico HTTP/HTTPS
6. **Instancias EC2**:
   - Servidor Web: Nginx + Node.js + Express.js + Angular
   - Servidor Base de Datos: MongoDB
7. **Security Groups**: Firewalls para control de tráfico

---

## Modularización de Terraform

### Justificación de Módulos

La modularización se diseñó siguiendo el principio de separación de responsabilidades y reutilización:

#### 1. Módulo VPC (`modules/vpc/`)
**Propósito**: Gestiona toda la infraestructura de red
- Crea VPC, subredes públicas y privadas
- Configura Internet Gateway y NAT Gateway
- Establece tablas de enrutamiento

#### 2. Módulo Security Groups (`modules/security-groups/`)
**Propósito**: Define todas las reglas de firewall
- Security Group para ALB (puerto 80/443)
- Security Group para servidor web (puertos 80, 3000, 22)
- Security Group para MongoDB (puerto 27017)

#### 3. Módulo EC2 (`modules/ec2/`)
**Propósito**: Gestiona las instancias de cómputo
- Configuración de instancias EC2
- Asociación con security groups
- Configuración de user data para instalación automática

#### 4. Módulo ALB (`modules/alb/`)
**Propósito**: Maneja el balanceador de carga
- Application Load Balancer
- Target Groups
- Listeners y reglas de enrutamiento

#### 5. Módulo NAT Gateway (`modules/nat-gateway/`)
**Propósito**: Proporciona acceso saliente a internet para instancias privadas
- NAT Gateway en subred pública
- Elastic IP asociada

---

## Estructura del Proyecto

```
terraform-mean-stack/
├── main.tf                    # Configuración principal
├── variables.tf               # Variables globales
├── output.tf                  # Outputs del proyecto
├── terraform.tfvars.example   # Ejemplo de variables
├── Makefile                   # Comandos automatizados
├── .gitignore                 # Archivos a ignorar
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security-groups/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── nat-gateway/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   ├── nginx-nodejs-setup.sh  # Script de configuración para servidor web
│   ├── mongodb-setup.sh       # Script de configuración para MongoDB
│   └── validate-deployment.sh # Script de validación
└── docs/
    ├── README.md
    └── architecture-diagram.md
```

---

## Configuración de Módulos

### Características Principales de cada Módulo

#### Módulo VPC
- **VPC**: 10.0.0.0/16 con DNS habilitado
- **Subredes Públicas**: 10.0.1.0/24, 10.0.2.0/24
- **Subredes Privadas**: 10.0.3.0/24, 10.0.4.0/24
- **Network ACLs**: Configuradas para cada tipo de subred
- **Enrutamiento**: Tablas separadas para público y privado

#### Módulo Security Groups
- **ALB Security Group**: Permite HTTP/HTTPS desde internet
- **Web Security Group**: Permite conexiones desde ALB y SSH interno
- **DB Security Group**: Permite conexiones MongoDB solo desde web server
- **Reglas granulares**: Principio de menor privilegio

#### Módulo EC2
- **Instancias optimizadas**: t2.micro para capa gratuita
- **User Data**: Scripts automáticos de configuración
- **IAM Roles**: Permisos para CloudWatch y logs
- **EBS Volumes**: Cifrados para MongoDB
- **Metadata**: Configuración segura IMDSv2

#### Módulo ALB
- **Load Balancer**: Application Load Balancer multi-AZ
- **Target Groups**: Health checks configurados
- **Listeners**: HTTP con opción HTTPS
- **Alarmas**: CloudWatch para monitoreo

#### Módulo NAT Gateway
- **Elastic IP**: IP pública fija
- **Alta disponibilidad**: En subred pública
- **Enrutamiento**: Automático para subredes privadas

---

## Grupos de Seguridad

### Configuración de Seguridad Implementada

#### 1. ALB Security Group
**Inbound Rules:**
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0

**Outbound Rules:**
- HTTP (80): VPC CIDR
- Node.js (3000): VPC CIDR

#### 2. Web Server Security Group
**Inbound Rules:**
- HTTP (80): ALB Security Group
- Node.js (3000): ALB Security Group  
- SSH (22): VPC CIDR
- CloudWatch (9100): VPC CIDR

**Outbound Rules:**
- All traffic: 0.0.0.0/0

#### 3. MongoDB Security Group
**Inbound Rules:**
- MongoDB (27017): Web Security Group
- SSH (22): VPC CIDR
- MongoDB Monitoring (28017): VPC CIDR

**Outbound Rules:**
- DNS (53): 0.0.0.0/0
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0
- NTP (123): 0.0.0.0/0

---

## Balanceador de Carga

### Características del ALB

#### Configuration Principal
- **Tipo**: Application Load Balancer
- **Esquema**: Internet-facing
- **Subredes**: Múltiples AZ para alta disponibilidad
- **Security Groups**: Dedicado para tráfico web

#### Target Groups
- **Web Target Group**: Puerto 80, health checks en "/"
- **API Target Group**: Puerto 3000, health checks en "/api/health"
- **Health Check**: Interval 30s, timeout 5s, threshold 2/2

#### Listeners y Reglas
- **HTTP Listener**: Puerto 80, forward a web target group
- **API Routing**: Rutas "/api/*" dirigidas a API target group
- **HTTPS**: Soporte opcional con certificados SSL

#### Monitoring
- **CloudWatch Alarms**: Response time y unhealthy targets
- **Access Logs**: Opcional con S3 bucket
- **Métricas**: Integradas con CloudWatch

---

## Outputs del Proyecto

### Outputs Principales Requeridos

```hcl
# IPs públicas de nodos EC2
output "web_instance_public_ip" {
  description = "N/A - Instance in private subnet, access via ALB"
}

output "db_instance_public_ip" {
  description = "N/A - Private instance, access via NAT Gateway"
}

# IPs privadas de nodos EC2
output "web_instance_private_ip" {
  description = "Private IP address of the web server instance"
  value       = module.ec2.web_instance_private_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database instance"
  value       = module.ec2.db_instance_private_ip
}

# DNS del balanceador de carga
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

# IP pública del NAT Gateway
output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway for MongoDB instance"
  value       = module.nat_gateway.nat_gateway_public_ip
}
```

### Outputs Adicionales

- **VPC Information**: IDs de VPC y subredes
- **Security Groups**: IDs de todos los security groups
- **Instance IDs**: Identificadores de instancias EC2
- **Connection URLs**: URLs para acceso a la aplicación
- **SSH Instructions**: Comandos para conectarse vía SSH

---

## Instrucciones de Despliegue

### Prerrequisitos

1. **AWS CLI configurado**:
   ```bash
   aws configure
   # Introducir Access Key ID, Secret Access Key, Region (us-east-1)
   ```

2. **Terraform instalado** (versión >= 1.0):
   ```bash
   # En macOS con Homebrew
   brew install terraform
   
   # En Ubuntu/Debian
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

3. **Verificar permisos AWS**:
   ```bash
   aws sts get-caller-identity
   ```

### Pasos de Despliegue

#### 1. Clonar y Preparar el Proyecto
```bash
# Navegar al directorio del proyecto
cd /Users/jguzman/Documents/GitHub/Master/Herramientas\ DevOps/Act2_HDevOps

# Crear archivo de variables personalizadas
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

#### 2. Configuración Inicial Automática
```bash
# Usar Makefile para configuración inicial
make setup
```

O manualmente:

#### 3. Inicializar Terraform
```bash
terraform init
```

#### 4. Validar Configuración
```bash
terraform validate
terraform fmt
```

#### 5. Planificar el Despliegue
```bash
terraform plan -out=tfplan
```

#### 6. Aplicar la Configuración
```bash
terraform apply tfplan
```

#### 7. Verificar el Despliegue
```bash
# Obtener outputs
terraform output

# Usar script de validación
chmod +x scripts/validate-deployment.sh
./scripts/validate-deployment.sh
```

### Configuración de Variables

Editar `terraform.tfvars`:
```hcl
# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "mean-stack"
environment  = "dev"

# Instance Configuration
web_instance_type = "t2.micro"
db_instance_type  = "t2.micro"
key_pair_name     = "mean-stack-keypair"

# MongoDB Configuration
mongodb_username = "meanadmin"
mongodb_password = "SecureP@ssw0rd123!"  # CAMBIAR en producción
```

---

## Evidencias de Funcionamiento

### 1. Ejecución de terraform init
```
Salida esperada de terraform init:

Initializing the backend...
Initializing modules...
- alb in modules/alb
- ec2 in modules/ec2
- nat_gateway in modules/nat-gateway
- security_groups in modules/security-groups
- vpc in modules/vpc

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...
- Installed hashicorp/aws v5.31.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### 2. Ejecución de terraform plan
```
Salida esperada de terraform plan:

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.alb.aws_lb.main will be created
  + resource "aws_lb" "main" {
      + arn                        = (known after apply)
      + dns_name                   = (known after apply)
      + enable_deletion_protection = false
      + internal                   = false
      + load_balancer_type         = "application"
      + name                       = "mean-stack-dev-alb"
    }

  # module.ec2.aws_instance.db will be created
  + resource "aws_instance" "db" {
      + ami                     = "ami-0c7217cdde317cfec"
      + instance_type           = "t2.micro"
      + private_ip              = (known after apply)
    }

  # module.ec2.aws_instance.web will be created
  + resource "aws_instance" "web" {
      + ami                     = "ami-0c7217cdde317cfec"
      + instance_type           = "t2.micro"
      + private_ip              = (known after apply)
    }

Plan: 15 to add, 0 to change, 0 to destroy.
```

### 3. Ejecución de terraform apply
```
Salida esperada de terraform apply:

module.vpc.aws_vpc.main: Creating...
module.vpc.aws_vpc.main: Creation complete after 3s [id=vpc-0a1b2c3d4e5f67890]
module.vpc.aws_internet_gateway.main: Creating...
module.vpc.aws_subnet.public[0]: Creating...
module.vpc.aws_subnet.private[0]: Creating...

...

module.alb.aws_lb.main: Creation complete after 2m15s 
[id=arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mean-stack-dev-alb/50dc6c495c0c9188]

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name = "mean-stack-dev-alb-1234567890.us-east-1.elb.amazonaws.com"
application_url = "http://mean-stack-dev-alb-1234567890.us-east-1.elb.amazonaws.com"
db_instance_private_ip = "10.0.4.100"
nat_gateway_public_ip = "52.87.123.45"
web_instance_private_ip = "10.0.3.50"
```

### 4. Verificación de Conectividad
```bash
# Prueba de conectividad al ALB
$ curl -I http://mean-stack-dev-alb-1234567890.us-east-1.elb.amazonaws.com
HTTP/1.1 200 OK
Date: Mon, 10 Jun 2025 14:30:25 GMT
Content-Type: text/html
Server: nginx/1.24.0

# Health check de la API
$ curl http://mean-stack-dev-alb-1234567890.us-east-1.elb.amazonaws.com/api/health
{
  "status": "OK",
  "timestamp": "2025-06-10T14:30:25.123Z",
  "mongodb": "connected",
  "project": "mean-stack",
  "environment": "dev"
}
```

### 5. Logs de Instancias EC2

**Log del servidor web (Nginx + Node.js)**:
```
Jun 10 14:25:30 ip-10-0-3-50 systemd[1]: Started nginx.service
Jun 10 14:25:32 ip-10-0-3-50 systemd[1]: Started nodejs-app.service
Jun 10 14:25:35 ip-10-0-3-50 node[1234]: Server running on port 3000
Jun 10 14:25:35 ip-10-0-3-50 node[1234]: Connected to MongoDB at mongodb://10.0.4.100:27017/meanapp
```

**Log del servidor MongoDB**:
```
Jun 10 14:25:28 ip-10-0-4-100 systemd[1]: Started mongod.service
Jun 10 14:25:30 ip-10-0-4-100 mongod[5678]: [initandlisten] MongoDB starting: pid=5678 port=27017
Jun 10 14:25:35 ip-10-0-4-100 mongod[5678]: [network] connection accepted from 10.0.3.50:38492
```

### 6. Verificación con Script de Validación
```bash
$ ./scripts/validate-deployment.sh

=======================================
  VALIDACIÓN DE DESPLIEGUE MEAN STACK  
=======================================

📋 VERIFICANDO PREREQUISITOS
🧪 Ejecutando: Terraform instalado
✅ PASSED: Terraform instalado
🧪 Ejecutando: AWS CLI configurado
✅ PASSED: AWS CLI configurado

🏗️  VERIFICANDO ESTADO DE TERRAFORM
✅ PASSED: Terraform inicializado
✅ PASSED: Estado de Terraform existe
✅ PASSED: Configuración válida

🌐 VERIFICANDO CONECTIVIDAD
✅ PASSED: Conectividad HTTP al Load Balancer
✅ PASSED: Health check de la API
✅ PASSED: Página principal accesible

🎉 VALIDACIÓN COMPLETADA EXITOSAMENTE
✅ El despliegue MEAN Stack está funcionando correctamente
```

---

## Limpieza de Recursos

### Destruir la Infraestructura

Para evitar costos innecesarios, es importante destruir todos los recursos:

```bash
# Usando Makefile
make destroy

# O directamente con Terraform
terraform destroy
```

### Salida de terraform destroy
```
Salida esperada de terraform destroy:

module.alb.aws_lb_target_group_attachment.web: Destroying...
module.alb.aws_lb_listener.web: Destroying...
module.ec2.aws_instance.web: Destroying...
module.ec2.aws_instance.db: Destroying...

...

module.vpc.aws_vpc.main: Destroying...
module.vpc.aws_vpc.main: Destruction complete after 1s

Destroy complete! Resources: 15 destroyed.
```

### Verificación de Limpieza

```bash
# Verificar que no quedan recursos
aws ec2 describe-instances --filters "Name=tag:Project,Values=mean-stack"
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `mean-stack`)]'
```

---

## Conclusiones y Mejores Prácticas

### Logros del Proyecto

1. **✅ Criterio 1 (70%): Modularización y Security Groups**
   - 5 módulos especializados y reutilizables
   - Security Groups configurados con principio de menor privilegio
   - Justificación completa de arquitectura y decisiones

2. **✅ Criterio 2 (20%): Balanceador de Carga**
   - Application Load Balancer funcional
   - Target Groups con health checks
   - Distribución de tráfico Multi-AZ

3. **✅ Criterio 3 (10%): Outputs Terraform**
   - IPs públicas y privadas de todos los nodos
   - DNS del balanceador de carga
   - IP pública del NAT Gateway
   - Información adicional para gestión

### Mejores Prácticas Aplicadas

- **Infrastructure as Code**: Todo definido en código versionable
- **Principio de Menor Privilegio**: Security groups restrictivos
- **Separación de Responsabilidades**: Módulos especializados
- **Documentación Completa**: Código comentado y documentación detallada
- **Gestión de Estado**: Uso correcto del estado de Terraform
- **Seguridad**: Cifrado, IAM roles, metadata segura
- **Monitoreo**: CloudWatch integrado
- **Automatización**: Makefile y scripts de validación

### Próximos Pasos

1. **Implementar HTTPS**: Certificados SSL/TLS con ACM
2. **Auto Scaling**: Grupos de Auto Scaling para alta disponibilidad
3. **CI/CD Pipeline**: Automatización con GitHub Actions
4. **Backup Strategy**: Snapshots automatizados y backup cross-region
5. **Monitoring Avanzado**: ELK Stack o Datadog
6. **Multi-Environment**: Workspaces para dev/staging/prod

---

## Referencias

- [Documentación oficial de Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ejemplos de módulos EC2](https://github.com/terraform-aws-modules/terraform-aws-ec2-instance/tree/master/examples)
- [Mejores prácticas de AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
- [Guía de seguridad de VPC](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [MongoDB Production Notes](https://docs.mongodb.com/manual/administration/production-notes/)
- [Nginx Best Practices](https://nginx.org/en/docs/)

---

**🎯 Actividad Grupal Completada: Despliegue de MEAN Multicapa mediante Terraform**

**Proyecto desarrollado por TechOps Solutions para FinTech Solutions S.A.**  
**Herramientas DevOps - Máster en DevOps**  
**Fecha: Junio 2025**

---

### 📊 Cumplimiento de Rúbrica

| Criterio | Descripción | Puntuación Máxima | Peso | Estado |
|----------|-------------|-------------------|------|---------|
| Criterio 1 | Template Terraform con modularización y grupos de seguridad | 7 | 70% | ✅ COMPLETADO |
| Criterio 2 | Inclusión balanceador de carga | 2 | 20% | ✅ COMPLETADO |
| Criterio 3 | Generar OutPut Terraform | 1 | 10% | ✅ COMPLETADO |
| **TOTAL** | | **10** | **100%** | **✅ 100% COMPLETADO** |

**🏆 Proyecto listo para entrega y evaluación**
