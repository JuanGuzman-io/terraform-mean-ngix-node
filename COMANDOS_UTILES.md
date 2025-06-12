# Referencia rápida de comandos

## 🚀 Comandos Rápidos para el Proyecto MEAN Stack

### Comandos de Terraform

```bash
# Configuración inicial completa
make setup

# Inicializar Terraform
terraform init

# Validar configuración
terraform validate

# Formatear archivos
terraform fmt -recursive

# Planificar cambios
terraform plan -out=tfplan

# Aplicar cambios
terraform apply tfplan

# Mostrar estado actual
terraform show

# Listar recursos
terraform state list

# Mostrar outputs
terraform output

# Destruir infraestructura
terraform destroy
```

### Comandos con Makefile

```bash
# Ver ayuda
make help

# Configuración inicial
make setup

# Verificar prerequisitos
make check-aws
make check-terraform

# Crear par de claves
make create-keypair

# Validar y formatear
make validate
make format

# Planificar y aplicar
make plan
make apply

# Probar aplicación
make test

# Ver logs
make logs

# Limpiar archivos temporales
make clean

# Destruir infraestructura
make destroy
```

### Comandos AWS CLI

```bash
# Verificar configuración
aws sts get-caller-identity

# Listar instancias EC2
aws ec2 describe-instances --filters "Name=tag:Project,Values=mean-stack"

# Verificar Load Balancers
aws elbv2 describe-load-balancers --names mean-stack-dev-alb

# Ver logs de CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/mean-stack"

# Obtener últimos logs
aws logs get-log-events --log-group-name "/aws/ec2/mean-stack-dev-web-server" --log-stream-name "i-xxxxxxxxx/setup.log"

# Verificar Security Groups
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=mean-stack"

# Listar NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=mean-stack"
```

### Scripts del Proyecto

```bash
# Hacer scripts ejecutables (si es necesario)
chmod +x scripts/*.sh

# Validar despliegue completo
./scripts/validate-deployment.sh

# Limpieza completa del proyecto
./scripts/cleanup.sh
```

### Debugging y Troubleshooting

```bash
# Ver estado detallado de Terraform
terraform show -json | jq '.'

# Refrescar estado
terraform refresh

# Importar recurso existente
terraform import aws_instance.example i-1234567890abcdef0

# Ver logs de Terraform
export TF_LOG=DEBUG
terraform apply

# Verificar conectividad a instancias
# (necesita bastion host para instancias privadas)
ssh -i mean-stack-keypair.pem ec2-user@BASTION_IP
ssh -i mean-stack-keypair.pem ec2-user@PRIVATE_IP

# Test de conectividad HTTP
curl -I http://$(terraform output -raw alb_dns_name)
curl http://$(terraform output -raw alb_dns_name)/api/health

# Verificar logs en instancias
sudo tail -f /var/log/mean-stack-setup.log
sudo systemctl status nginx mean-app mongod
sudo journalctl -u mean-app -f
```

### Comandos de Desarrollo Local (Docker)

```bash
# Levantar entorno local
docker-compose up -d

# Ver logs
docker-compose logs -f

# Entrar a contenedor
docker exec -it mean-nodejs-local bash
docker exec -it mean-mongodb-local mongosh

# Limpiar entorno local
docker-compose down -v
docker system prune -f
```

### Variables de Entorno Útiles

```bash
# Configurar región AWS
export AWS_DEFAULT_REGION=us-east-1

# Habilitar logs de Terraform
export TF_LOG=INFO
export TF_LOG_PATH=terraform.log

# Configurar workspace de Terraform
terraform workspace new dev
terraform workspace select dev

# Variables para scripts
export PROJECT_NAME=mean-stack
export ENVIRONMENT=dev
```

### Monitoreo y Métricas

```bash
# CloudWatch Metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/mean-stack-dev-alb/1234567890abcdef \
  --statistics Average \
  --start-time 2025-06-10T00:00:00Z \
  --end-time 2025-06-10T23:59:59Z \
  --period 3600

# Verificar health checks
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mean-stack-dev-web-tg/1234567890abcdef

# Ver métricas de instancias
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --statistics Average \
  --start-time 2025-06-10T00:00:00Z \
  --end-time 2025-06-10T23:59:59Z \
  --period 300
```

### Backup y Recuperación

```bash
# Backup de estado de Terraform
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Backup de MongoDB (ejecutar en instancia DB)
sudo -u mongod /opt/mongodb-backup.sh

# Crear snapshot de EBS
aws ec2 create-snapshot --volume-id vol-1234567890abcdef0 --description "MongoDB data backup $(date)"

# Listar snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=description,Values=MongoDB*"
```

### Seguridad

```bash
# Verificar configuración de Security Groups
aws ec2 describe-security-groups --group-ids sg-1234567890abcdef0

# Verificar configuración de IAM
aws iam get-role --role-name mean-stack-dev-ec2-role

# Verificar cifrado de volúmenes
aws ec2 describe-volumes --filters "Name=tag:Project,Values=mean-stack"

# Verificar configuración de VPC
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=mean-stack"
```

### Performance Testing

```bash
# Test de carga con Apache Bench
ab -n 1000 -c 10 http://$(terraform output -raw alb_dns_name)/

# Test con curl
curl -w "@curl-format.txt" -o /dev/null -s http://$(terraform output -raw alb_dns_name)/

# Crear archivo curl-format.txt
echo '     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
    time_pretransfer:  %{time_pretransfer}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n' > curl-format.txt
```

---

**📝 Referencia creada por TechOps Solutions**  
**Proyecto: MEAN Stack con Terraform en AWS**  
**Fecha: Junio 2025**
