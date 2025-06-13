#!/bin/bash
# scripts/mongodb-setup.sh - Script de configuración para MongoDB

set -e

# Variables del template (serán reemplazadas por Terraform)
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
MONGODB_USERNAME="${mongodb_username}"
MONGODB_PASSWORD="${mongodb_password}"

# Variables del sistema
LOG_FILE="/var/log/mongodb-setup.log"
MONGODB_VERSION="7.0"
MONGODB_DATA_DIR="/data/db"
MONGODB_LOG_DIR="/var/log/mongodb"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "=== Iniciando configuración de MongoDB ==="

# Actualizar el sistema
log "Actualizando paquetes del sistema..."
dnf update -y

# Instalar paquetes básicos
log "Instalando paquetes básicos..."
dnf install -y \
    curl \
    wget \
    nano \
    htop \
    openssl \
    firewalld \
    amazon-cloudwatch-agent \
    xfsprogs

# Configurar firewall
log "Configurando firewall..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-port=27017/tcp
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Configurar volumen EBS adicional para datos de MongoDB
log "Configurando volumen EBS para datos de MongoDB..."
if [ -b /dev/nvme1n1 ] || [ -b /dev/xvdf ]; then
    DEVICE="/dev/nvme1n1"
    [ -b /dev/xvdf ] && DEVICE="/dev/xvdf"
    
    log "Encontrado dispositivo EBS: $DEVICE"
    
    # Verificar si el dispositivo ya tiene un filesystem
    if ! blkid $DEVICE; then
        log "Creando filesystem XFS en $DEVICE..."
        mkfs.xfs $DEVICE
    fi
    
    # Crear directorio de datos
    mkdir -p $MONGODB_DATA_DIR
    
    # Montar el volumen
    mount $DEVICE $MONGODB_DATA_DIR
    
    # Agregar entrada al fstab para montaje automático
    DEVICE_UUID=$(blkid -s UUID -o value $DEVICE)
    echo "UUID=$DEVICE_UUID $MONGODB_DATA_DIR xfs defaults,nofail 0 2" >> /etc/fstab
    
    log "Volumen EBS montado exitosamente en $MONGODB_DATA_DIR"
else
    log "No se encontró volumen EBS adicional, usando directorio local"
    mkdir -p $MONGODB_DATA_DIR
fi

# Agregar repositorio de MongoDB
log "Agregando repositorio de MongoDB..."
cat > /etc/yum.repos.d/mongodb-org-$${MONGODB_VERSION}.repo << 'REPOEOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
REPOEOF

# Instalar MongoDB
log "Instalando MongoDB $MONGODB_VERSION..."
dnf install -y mongodb-org

# Crear directorios necesarios
log "Creando directorios para MongoDB..."
mkdir -p $MONGODB_DATA_DIR
mkdir -p $MONGODB_LOG_DIR
mkdir -p /etc/ssl/mongodb

# Crear usuario y establecer permisos
useradd -r -s /bin/false mongod 2>/dev/null || true
chown -R mongod:mongod $MONGODB_DATA_DIR
chown -R mongod:mongod $MONGODB_LOG_DIR
chmod 750 $MONGODB_DATA_DIR

# Generar certificado SSL auto-firmado para MongoDB
log "Generando certificado SSL para MongoDB..."
openssl req -new -x509 -days 3650 -nodes \
    -out /etc/ssl/mongodb/mongodb.crt \
    -keyout /etc/ssl/mongodb/mongodb.key \
    -subj "/C=US/ST=AWS/L=Cloud/O=TechOps/OU=DevOps/CN=mongodb.local"

cat /etc/ssl/mongodb/mongodb.key /etc/ssl/mongodb/mongodb.crt > /etc/ssl/mongodb/mongodb.pem
chown mongod:mongod /etc/ssl/mongodb/mongodb.pem
chmod 600 /etc/ssl/mongodb/mongodb.pem

# Configurar MongoDB
log "Configurando MongoDB..."
cat > /etc/mongod.conf << 'MONGOEOF'
# MongoDB configuration file

# Where to store data
storage:
  dbPath: /data/db
  journal:
    enabled: true
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5

# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
  ssl:
    mode: allowSSL
    PEMKeyFile: /etc/ssl/mongodb/mongodb.pem

# Logging
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
  pidFilePath: /var/run/mongodb/mongod.pid
  fork: true

# Security
security:
  authorization: enabled

# Operation profiling
operationProfiling:
  slowOpThresholdMs: 100
MONGOEOF

# Crear directorio para PID file
mkdir -p /var/run/mongodb
chown mongod:mongod /var/run/mongodb

# Configurar logrotate para MongoDB
cat > /etc/logrotate.d/mongodb << 'LOGEOF'
/var/log/mongodb/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    sharedscripts
    copytruncate
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
LOGEOF

# Configurar límites del sistema para MongoDB
cat > /etc/security/limits.d/99-mongodb-nproc.conf << 'LIMITSEOF'
mongod soft nproc 32000
mongod hard nproc 32000
mongod soft nofile 64000
mongod hard nofile 64000
LIMITSEOF

# Configurar parámetros del kernel para MongoDB
cat > /etc/sysctl.d/99-mongodb.conf << 'SYSCTLEOF'
# Disable Transparent Huge Pages
vm.nr_hugepages = 0

# Network tuning for MongoDB
net.core.somaxconn = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_max_syn_backlog = 4096
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-mongodb.conf

# Deshabilitar Transparent Huge Pages
echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag

# Hacer permanente la deshabilitación de THP
cat > /etc/systemd/system/disable-thp.service << 'THPEOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=basic.target
THPEOF

systemctl enable disable-thp.service

# Habilitar y iniciar MongoDB
log "Habilitando y iniciando MongoDB..."
systemctl enable mongod
systemctl start mongod

# Esperar a que MongoDB esté listo
log "Esperando a que MongoDB esté listo..."
sleep 10

# Verificar que MongoDB esté ejecutándose
for i in {1..30}; do
    if systemctl is-active --quiet mongod && mongosh --eval "db.adminCommand('ismaster')" >/dev/null 2>&1; then
        log "✅ MongoDB está ejecutándose correctamente"
        break
    fi
    log "Esperando a MongoDB... (intento $i/30)"
    sleep 2
done

# Crear usuario administrador
log "Configurando autenticación de MongoDB..."
mongosh --eval "
use admin
db.createUser({
  user: '${mongodb_username}',
  pwd: '${mongodb_password}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
})
" 2>/dev/null && log "✅ Usuario administrador creado" || log "❌ Error creando usuario administrador"

# Crear base de datos y usuario para la aplicación MEAN
log "Creando base de datos para aplicación MEAN..."
mongosh --authenticationDatabase admin -u "${mongodb_username}" -p "${mongodb_password}" --eval "
use meanapp
db.createUser({
  user: '${mongodb_username}',
  pwd: '${mongodb_password}',
  roles: [
    { role: 'readWrite', db: 'meanapp' }
  ]
})
db.items.insertOne({
  name: 'Item de prueba inicial',
  description: 'Este item fue creado durante la configuración inicial',
  createdAt: new Date(),
  environment: '${environment}',
  project: '${project_name}'
})
" 2>/dev/null && log "✅ Base de datos MEAN configurada" || log "❌ Error configurando base de datos MEAN"

# Configurar CloudWatch Agent
log "Configurando CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/mongodb-setup.log",
                        "log_group_name": "/aws/ec2/${project_name}-${environment}-db-server",
                        "log_stream_name": "{instance_id}/setup.log"
                    },
                    {
                        "file_path": "/var/log/mongodb/mongod.log",
                        "log_group_name": "/aws/ec2/${project_name}-${environment}-db-server",
                        "log_stream_name": "{instance_id}/mongod.log"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "AWS/EC2/Custom",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
CWEOF

# Iniciar CloudWatch Agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Verificar estado final
log "Verificando estado final de servicios..."
mongod_status=$(systemctl is-active mongod)
cloudwatch_status=$(systemctl is-active amazon-cloudwatch-agent)

log "Estado de servicios:"
log "  MongoDB: $mongod_status"
log "  CloudWatch Agent: $cloudwatch_status"

# Verificar conectividad a MongoDB
log "Verificando conectividad a MongoDB..."
mongosh --authenticationDatabase admin -u "${mongodb_username}" -p "${mongodb_password}" --eval "db.adminCommand('ping')" >/dev/null 2>&1 && log "✅ MongoDB accesible con autenticación" || log "❌ MongoDB no accesible"

# Mostrar información de la instancia
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo 'IP_NO_DISPONIBLE')
log "=== Configuración de MongoDB completada ==="
log "MongoDB ejecutándose en: $INSTANCE_IP:27017"
log "Base de datos: meanapp"
log "Usuario: ${mongodb_username}"
log "Autenticación: Habilitada"
log "SSL: Permitido"

# Crear script de backup simple
cat > /opt/mongodb-backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/opt/mongodb-backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

mongodump --authenticationDatabase admin -u ${mongodb_username} -p ${mongodb_password} --out $BACKUP_DIR/backup_$DATE

# Mantener solo los últimos 7 backups
find $BACKUP_DIR -type d -name "backup_*" -mtime +7 -exec rm -rf {} +

echo "Backup completado: $BACKUP_DIR/backup_$DATE"
BACKUPEOF

chmod +x /opt/mongodb-backup.sh
chown mongod:mongod /opt/mongodb-backup.sh

log "Script de backup creado en /opt/mongodb-backup.sh"
