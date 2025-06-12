#!/bin/bash
# Script de configuración para servidor web

set -e

# Variables del template (serán reemplazadas por Terraform)
MONGODB_PRIVATE_IP="${mongodb_private_ip}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
MONGODB_USERNAME="${mongodb_username}"
MONGODB_PASSWORD="${mongodb_password}"

# Variables del sistema
LOG_FILE="/var/log/mean-stack-setup.log"
NODEJS_VERSION="18"
APP_DIR="/opt/mean-app"
APP_USER="nodejs"

# Función de logging
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "=== Iniciando configuración del servidor web MEAN Stack ==="

# Actualizar el sistema
log "Actualizando paquetes del sistema..."
dnf update -y

# Instalar paquetes básicos
log "Instalando paquetes básicos..."
dnf install -y \
  curl \
  wget \
  git \
  unzip \
  htop \
  nano \
  nginx \
  openssl \
  firewalld \
  amazon-cloudwatch-agent

# Configurar firewall
log "Configurando firewall..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --reload

# Instalar Node.js y npm
log "Instalando Node.js $NODEJS_VERSION..."
curl -fsSL https://rpm.nodesource.com/setup_$NODEJS_VERSION.x | bash -
dnf install -y nodejs

# Verificar instalación de Node.js
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js instalado: $node_version"
log "npm instalado: $npm_version"

# Crear usuario para la aplicación
log "Creando usuario para la aplicación..."
useradd -r -s /bin/false $APP_USER
usermod -a -G nginx $APP_USER

# Crear directorio de la aplicación
log "Creando directorio de la aplicación..."
mkdir -p $APP_DIR
chown $APP_USER:$APP_USER $APP_DIR

# Crear aplicación MEAN básica
log "Configurando aplicación Node.js..."
cat >$APP_DIR/package.json <<'EOF'
{
  "name": "mean-stack-app",
  "version": "1.0.0",
  "description": "MEAN Stack Application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "mongoose": "^7.5.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.3.0",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# Crear servidor Express.js
cat >$APP_DIR/server.js <<EOF
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir archivos estáticos
app.use(express.static('public'));

// Conexión a MongoDB
const MONGODB_URI = \`mongodb://$MONGODB_USERNAME:$MONGODB_PASSWORD@$MONGODB_PRIVATE_IP:27017/meanapp\`;

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => {
  console.log('Conectado a MongoDB exitosamente');
})
.catch((error) => {
  console.error('Error conectando a MongoDB:', error);
});

// Esquema y modelo de ejemplo
const itemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: String,
  createdAt: { type: Date, default: Date.now }
});

const Item = mongoose.model('Item', itemSchema);

// Rutas de la API
app.get('/', (req, res) => {
  res.send(\`
    <html>
      <head>
        <title>MEAN Stack Application</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .header { color: #333; }
          .status { background: #e8f5e8; padding: 10px; border-radius: 5px; }
          .endpoints { background: #f0f0f0; padding: 15px; border-radius: 5px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <h1 class="header">🚀 MEAN Stack Application</h1>
        <div class="status">
          <h2>✅ Aplicación funcionando correctamente</h2>
          <p><strong>Proyecto:</strong> $PROJECT_NAME</p>
          <p><strong>Ambiente:</strong> $ENVIRONMENT</p>
          <p><strong>Node.js:</strong> \${process.version}</p>
          <p><strong>MongoDB:</strong> Conectado a $MONGODB_PRIVATE_IP:27017</p>
        </div>
        <div class="endpoints">
          <h3>API Endpoints disponibles:</h3>
          <ul>
            <li><strong>GET /</strong> - Esta página</li>
            <li><strong>GET /api/health</strong> - Health check</li>
            <li><strong>GET /api/items</strong> - Listar todos los items</li>
            <li><strong>POST /api/items</strong> - Crear nuevo item</li>
            <li><strong>GET /api/items/:id</strong> - Obtener item por ID</li>
            <li><strong>DELETE /api/items/:id</strong> - Eliminar item</li>
          </ul>
        </div>
      </body>
    </html>
  \`);
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    project: '$PROJECT_NAME',
    environment: '$ENVIRONMENT'
  });
});

// CRUD endpoints para items
app.get('/api/items', async (req, res) => {
  try {
    const items = await Item.find();
    res.json(items);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/items', async (req, res) => {
  try {
    const item = new Item(req.body);
    await item.save();
    res.status(201).json(item);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get('/api/items/:id', async (req, res) => {
  try {
    const item = await Item.findById(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item no encontrado' });
    }
    res.json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/items/:id', async (req, res) => {
  try {
    const item = await Item.findByIdAndDelete(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item no encontrado' });
    }
    res.json({ message: 'Item eliminado exitosamente' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Manejo de errores
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Algo salió mal!' });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(\`Servidor ejecutándose en puerto \${PORT}\`);
  console.log(\`Ambiente: $ENVIRONMENT\`);
  console.log(\`Proyecto: $PROJECT_NAME\`);
});
EOF

# Crear archivo de configuración de ambiente
cat >$APP_DIR/.env <<EOF
NODE_ENV=$ENVIRONMENT
PORT=3000
MONGODB_URI=mongodb://$MONGODB_USERNAME:$MONGODB_PASSWORD@$MONGODB_PRIVATE_IP:27017/meanapp
PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT
EOF

# Crear directorio public con archivo de ejemplo
mkdir -p $APP_DIR/public
cat >$APP_DIR/public/index.html <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MEAN Stack App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; margin-bottom: 30px; }
        .api-section { background: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 5px; }
        button:hover { background: #0056b3; }
        .result { background: #e9ecef; padding: 15px; border-radius: 5px; margin-top: 10px; min-height: 50px; }
        input { padding: 8px; margin: 5px; border: 1px solid #ddd; border-radius: 3px; width: 200px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 MEAN Stack Application</h1>
            <p>Frontend de prueba para la API</p>
        </div>
        
        <div class="api-section">
            <h3>Health Check</h3>
            <button onclick="checkHealth()">Verificar Estado de la API</button>
            <div id="health-result" class="result"></div>
        </div>
        
        <div class="api-section">
            <h3>Gestión de Items</h3>
            <button onclick="getItems()">Listar Items</button>
            <button onclick="createSampleItem()">Crear Item de Prueba</button>
            <div>
                <input type="text" id="item-name" placeholder="Nombre del item">
                <input type="text" id="item-description" placeholder="Descripción">
                <button onclick="createCustomItem()">Crear Item Personalizado</button>
            </div>
            <div id="items-result" class="result"></div>
        </div>
    </div>

    <script>
        async function checkHealth() {
            try {
                const response = await fetch('/api/health');
                const data = await response.json();
                document.getElementById('health-result').innerHTML = `
                    <strong>Estado:</strong> ${data.status}<br>
                    <strong>MongoDB:</strong> ${data.mongodb}<br>
                    <strong>Timestamp:</strong> ${data.timestamp}<br>
                    <strong>Proyecto:</strong> ${data.project}<br>
                    <strong>Ambiente:</strong> ${data.environment}
                `;
            } catch (error) {
                document.getElementById('health-result').innerHTML = `<strong>Error:</strong> ${error.message}`;
            }
        }

        async function getItems() {
            try {
                const response = await fetch('/api/items');
                const items = await response.json();
                document.getElementById('items-result').innerHTML = `
                    <strong>Items (${items.length}):</strong><br>
                    <pre>${JSON.stringify(items, null, 2)}</pre>
                `;
            } catch (error) {
                document.getElementById('items-result').innerHTML = `<strong>Error:</strong> ${error.message}`;
            }
        }

        async function createSampleItem() {
            const sampleItem = {
                name: `Item de prueba ${Date.now()}`,
                description: `Creado automáticamente el ${new Date().toLocaleString()}`
            };
            
            try {
                const response = await fetch('/api/items', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(sampleItem)
                });
                const item = await response.json();
                document.getElementById('items-result').innerHTML = `
                    <strong>Item creado:</strong><br>
                    <pre>${JSON.stringify(item, null, 2)}</pre>
                `;
            } catch (error) {
                document.getElementById('items-result').innerHTML = `<strong>Error:</strong> ${error.message}`;
            }
        }

        async function createCustomItem() {
            const name = document.getElementById('item-name').value;
            const description = document.getElementById('item-description').value;
            
            if (!name) {
                alert('Por favor ingresa un nombre para el item');
                return;
            }
            
            try {
                const response = await fetch('/api/items', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name, description })
                });
                const item = await response.json();
                document.getElementById('items-result').innerHTML = `
                    <strong>Item personalizado creado:</strong><br>
                    <pre>${JSON.stringify(item, null, 2)}</pre>
                `;
                document.getElementById('item-name').value = '';
                document.getElementById('item-description').value = '';
            } catch (error) {
                document.getElementById('items-result').innerHTML = `<strong>Error:</strong> ${error.message}`;
            }
        }

        // Verificar estado al cargar la página
        window.onload = checkHealth;
    </script>
</body>
</html>
EOF

# Cambiar propietario de archivos
chown -R $APP_USER:$APP_USER $APP_DIR

# Instalar dependencias de Node.js
log "Instalando dependencias de Node.js..."
cd $APP_DIR
sudo -u $APP_USER npm install

# Configurar Nginx
log "Configurando Nginx..."
cat >/etc/nginx/conf.d/mean-app.conf <<'EOF'
upstream nodejs_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name _;
    
    # Logs
    access_log /var/log/nginx/mean-app-access.log;
    error_log /var/log/nginx/mean-app-error.log;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
    # Static files
    location /static {
        alias /opt/mean-app/public;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API routes
    location /api {
        proxy_pass http://nodejs_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Default route to Node.js
    location / {
        proxy_pass http://nodejs_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Crear servicio systemd para la aplicación Node.js
log "Configurando servicio systemd..."
cat >/etc/systemd/system/mean-app.service <<EOF
[Unit]
Description=MEAN Stack Node.js Application
Documentation=https://github.com/techops-solutions/mean-stack
After=network.target mongodb.service

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=$ENVIRONMENT
Environment=PORT=3000
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF

# Configurar logrotate para los logs de la aplicación
cat >/etc/logrotate.d/mean-app <<'EOF'
/var/log/mean-stack-setup.log
/var/log/nginx/mean-app-*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0644 nginx nginx
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            /bin/kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
EOF

# Configurar CloudWatch Agent
log "Configurando CloudWatch Agent..."
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
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
                        "file_path": "/var/log/mean-stack-setup.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT-web-server",
                        "log_stream_name": "{instance_id}/setup.log"
                    },
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT-web-server",
                        "log_stream_name": "{instance_id}/nginx-access.log"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT-web-server",
                        "log_stream_name": "{instance_id}/nginx-error.log"
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
            "diskio": {
                "measurement": [
                    "io_time"
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
EOF

# Habilitar y iniciar servicios
log "Habilitando y iniciando servicios..."
systemctl daemon-reload
systemctl enable nginx
systemctl enable mean-app
systemctl enable amazon-cloudwatch-agent

# Iniciar servicios
systemctl start nginx
systemctl start mean-app
systemctl start amazon-cloudwatch-agent

# Verificar estado de servicios
sleep 10
nginx_status=$(systemctl is-active nginx)
app_status=$(systemctl is-active mean-app)
cloudwatch_status=$(systemctl is-active amazon-cloudwatch-agent)

log "Estado de servicios:"
log "  Nginx: $nginx_status"
log "  MEAN App: $app_status"
log "  CloudWatch Agent: $cloudwatch_status"

# Verificar conectividad a MongoDB
log "Verificando conectividad a MongoDB..."
timeout 10 bash -c "cat < /dev/null > /dev/tcp/$MONGODB_PRIVATE_IP/27017" && log "✅ MongoDB accesible" || log "❌ MongoDB no accesible"

# Verificar aplicación local
log "Verificando aplicación local..."
sleep 5
curl -f http://localhost:3000/api/health && log "✅ Aplicación Node.js funcionando" || log "❌ Aplicación Node.js no responde"

log "=== Configuración del servidor web completada ==="
log "Aplicación disponible en: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'IP_NO_DISPONIBLE')"
log "Health check: http://localhost/api/health"
