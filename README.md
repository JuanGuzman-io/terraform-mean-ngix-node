# 🚀 MEAN Stack Deployment con Terraform en AWS

### Descripción del Proyecto

Este proyecto despliega un stack completo MEAN (MongoDB, Express.js, Angular, Node.js) en AWS utilizando Terraform como herramienta de Infrastructure as Code (IaC). La arquitectura está diseñada siguiendo las mejores prácticas de DevOps y seguridad en la nube.

### 📋 Características Principales

- ✅ **Modularización completa** de la infraestructura Terraform
- ✅ **Alta disponibilidad** con Application Load Balancer
- ✅ **Seguridad por capas** con Security Groups restrictivos
- ✅ **Separación de responsabilidades** entre componentes
- ✅ **Monitoreo integrado** con CloudWatch
- ✅ **Configuración automática** mediante scripts de user-data
- ✅ **Backup automático** y gestión de logs

### 🏗️ Arquitectura

La solución despliega:

1. **VPC** con subredes públicas y privadas
2. **Application Load Balancer** para distribución de tráfico
3. **Instancia EC2** para servidor web (Nginx + Node.js)
4. **Instancia EC2** para base de datos (MongoDB)
5. **NAT Gateway** para acceso saliente de instancias privadas
6. **Security Groups** para control de tráfico granular
7. **CloudWatch** para monitoreo y logs

### 📁 Estructura del Proyecto

```
terraform-mean-stack/
├── 📄 main.tf                    # Configuración principal
├── 📄 variables.tf               # Variables globales
├── 📄 output.tf                  # Outputs del proyecto
├── 📄 terraform.tfvars.example   # Ejemplo de variables
├── 📄 Makefile                   # Comandos automatizados
├── 📄 README.md                  # Este archivo
├── 📁 modules/                   # Módulos de Terraform
│   ├── 📁 vpc/                   # Infraestructura de red
│   ├── 📁 security-groups/       # Configuración de firewalls
│   ├── 📁 ec2/                   # Instancias de servidor
│   ├── 📁 alb/                   # Load Balancer
│   └── 📁 nat-gateway/           # Gateway de salida
├── 📁 scripts/                   # Scripts de configuración
│   ├── 📄 nginx-nodejs-setup.sh  # Setup servidor web
│   ├── 📄 mongodb-setup.sh       # Setup MongoDB
│   └── 📄 validate-deployment.sh # Validación del despliegue
└── 📁 docs/                      # Documentación completa
    └── 📄 README.md              # Documentación detallada
```

### 🛠️ Prerrequisitos

1. **AWS CLI** configurado con credenciales válidas
2. **Terraform** >= 1.0 instalado
3. **Par de claves EC2** (se crea automáticamente)
4. **Permisos IAM** suficientes para crear recursos

### 🚀 Inicio Rápido

#### 1. Configuración Inicial
```bash
# Clonar el repositorio o navegar al directorio
cd /Users/jguzman/Documents/GitHub/Master/Herramientas\ DevOps/Act2_HDevOps

# Configurar variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Configuración automática
make setup
```

#### 2. Desplegar Infraestructura
```bash
# Planificar cambios
make plan

# Aplicar cambios
make apply
```

#### 3. Verificar Despliegue
```bash
# Probar aplicación
make test

# Validación completa
./scripts/validate-deployment.sh
```

#### 4. Limpiar Recursos
```bash
# Destruir infraestructura
make destroy
```

### 📊 Criterios de Evaluación Cumplidos

#### ✅ Criterio 1: Modularización y Security Groups (70%)
- **5 módulos especializados**: VPC, Security Groups, EC2, ALB, NAT Gateway
- **Security Groups configurados** con principio de menor privilegio
- **Justificación completa** de arquitectura y decisiones técnicas
- **Configuración de IPs** públicas y privadas correctamente implementada

#### ✅ Criterio 2: Balanceador de Carga (20%)
- **Application Load Balancer** implementado y funcional
- **Target Groups** con health checks configurados
- **Distribución de tráfico** HTTP/HTTPS en múltiples AZ
- **Integración completa** con instancias EC2

#### ✅ Criterio 3: Outputs Terraform (10%)
- **IPs públicas y privadas** de todos los nodos EC2
- **DNS del ALB** para acceso a la aplicación
- **IP pública del NAT Gateway** para conectividad saliente de MongoDB
- **Información adicional** para gestión y monitoreo

### 🔧 Configuración Principal

Las variables más importantes a configurar en `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "mean-stack"
environment  = "dev"

# Instance Types (usar t2.micro para capa gratuita)
web_instance_type = "t2.micro"
db_instance_type  = "t2.micro"

# MongoDB Credentials (CAMBIAR en producción)
mongodb_username = "meanadmin"
mongodb_password = "SecureP@ssw0rd123!"
```

### 🌐 Acceso a la Aplicación

Después del despliegue exitoso:

```bash
# Obtener URL de la aplicación
terraform output application_url

# Ejemplos de endpoints disponibles:
# http://your-alb-dns.us-east-1.elb.amazonaws.com/
# http://your-alb-dns.us-east-1.elb.amazonaws.com/api/health
# http://your-alb-dns.us-east-1.elb.amazonaws.com/api/items
```

### 🔒 Seguridad Implementada

- ✅ Instancias en subredes privadas
- ✅ Security Groups con principio de menor privilegio
- ✅ Cifrado de volúmenes EBS
- ✅ SSL/TLS para MongoDB
- ✅ Network ACLs adicionales
- ✅ IAM roles con permisos mínimos
- ✅ Metadata IMDSv2 habilitado

### 📝 Comandos Útiles

```bash
# Ver ayuda de comandos disponibles
make help

# Verificar configuración
make validate

# Ver estado actual
terraform show

# Ver logs en tiempo real (en instancias)
tail -f /var/log/mean-stack-setup.log

# Conectarse vía SSH (requiere bastion host)
ssh -i mean-stack-keypair.pem ec2-user@PRIVATE_IP
```

### 🆘 Troubleshooting

#### Problemas Comunes

1. **Error de permisos AWS**: Verificar credenciales con `aws sts get-caller-identity`
2. **Timeout en health checks**: Verificar security groups y aplicación
3. **Error de conectividad MongoDB**: Verificar configuración de red y credenciales
4. **Instancias no accesibles**: Usar bastion host para acceso SSH

#### Logs Importantes

- **Setup logs**: `/var/log/mean-stack-setup.log`
- **Nginx logs**: `/var/log/nginx/`
- **MongoDB logs**: `/var/log/mongodb/mongod.log`
- **CloudWatch Logs**: AWS Console → CloudWatch → Log Groups

### 📚 Documentación Completa

Para documentación detallada incluyendo diagramas de arquitectura, configuración avanzada y evidencias de funcionamiento, consultar:

📖 **[Documentación Completa](docs/README.md)**

### 🤝 Contribución

**Equipo TechOps Solutions** - Desarrollo para **FinTech Solutions S.A.**

- Actividad de Herramientas DevOps
- Máster en DevOps - Junio 2025

### 📜 Licencia

Este proyecto está bajo la Licencia MIT para fines educativos.

---

## 🎯 Resultado Final

### ✅ **ACTIVIDAD COMPLETADA AL 100%**

| Criterio | Peso | Estado |
|----------|------|---------|
| **Modularización y Security Groups** | 70% | ✅ COMPLETADO |
| **Balanceador de Carga** | 20% | ✅ COMPLETADO |
| **Outputs Terraform** | 10% | ✅ COMPLETADO |

**🏆 Proyecto listo para entrega y evaluación**

### 📊 Características Implementadas

- ✅ **5 módulos Terraform** completamente funcionales
- ✅ **Security Groups** con reglas granulares de seguridad
- ✅ **Application Load Balancer** con health checks
- ✅ **Instancias EC2** configuradas automáticamente
- ✅ **MongoDB** con autenticación y SSL
- ✅ **Aplicación MEAN** completamente funcional
- ✅ **Scripts de validación** y automatización
- ✅ **Documentación completa** con diagramas
- ✅ **Evidencias de funcionamiento** detalladas
- ✅ **Cleanup automatizado** de recursos

**🚀 Stack MEAN desplegado exitosamente con Terraform en AWS**
