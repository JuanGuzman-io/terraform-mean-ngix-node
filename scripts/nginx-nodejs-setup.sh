#!/bin/bash
# Compact MEAN Stack setup script
set -e

# Variables
MONGODB_PRIVATE_IP="${mongodb_private_ip}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
MONGODB_USERNAME="${mongodb_username}"
MONGODB_PASSWORD="${mongodb_password}"
LOG_FILE="/var/log/mean-setup.log"
APP_DIR="/opt/mean-app"
APP_USER="nodejs"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE; }

log "=== Iniciando configuración MEAN Stack ==="

# Sistema base
dnf update -y
dnf install -y curl wget git nginx openssl firewalld amazon-cloudwatch-agent

# Firewall
systemctl enable firewalld && systemctl start firewalld
firewall-cmd --permanent --add-service={http,https,ssh} --add-port=3000/tcp
firewall-cmd --reload

# Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Usuario y directorio
useradd -r -s /bin/false $APP_USER
mkdir -p $APP_DIR && chown $APP_USER:$APP_USER $APP_DIR

# package.json
cat >$APP_DIR/package.json <<EOF
{
  "name": "mean-app",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {"start": "node server.js"},
  "dependencies": {
    "express": "^4.18.0",
    "mongoose": "^7.5.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.3.0"
  }
}
EOF

# server.js
cat >$APP_DIR/server.js <<SERVEREOF
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet(), cors(), express.json());

const MONGODB_URI = 'mongodb://${mongodb_username}:${mongodb_password}@${mongodb_private_ip}:27017/meanapp';
mongoose.connect(MONGODB_URI).then(() => console.log('MongoDB conectado')).catch(console.error);

const itemSchema = new mongoose.Schema({
  name: {type: String, required: true},
  description: String,
  createdAt: {type: Date, default: Date.now}
});
const Item = mongoose.model('Item', itemSchema);

app.get('/', (req, res) => {
  res.send(\`<html><body><h1>MEAN Stack App</h1><p>Proyecto: ${project_name}</p><p>Ambiente: ${environment}</p><p>Node.js: $${process.version}</p><p>MongoDB: ${mongodb_private_ip}:27017</p><h3>Endpoints:</h3><ul><li>GET /api/health</li><li>GET /api/items</li><li>POST /api/items</li></ul></body></html>\`);
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    project: '${project_name}',
    environment: '${environment}'
  });
});

app.get('/api/items', async (req, res) => {
  try {
    const items = await Item.find();
    res.json(items);
  } catch (error) {
    res.status(500).json({error: error.message});
  }
});

app.post('/api/items', async (req, res) => {
  try {
    const item = new Item(req.body);
    await item.save();
    res.status(201).json(item);
  } catch (error) {
    res.status(400).json({error: error.message});
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(\`Servidor en puerto $${PORT}\`);
  console.log(\`Ambiente: ${environment}, Proyecto: ${project_name}\`);
});
SERVEREOF

# .env
cat >$APP_DIR/.env <<EOF
NODE_ENV=${environment}
PORT=3000
MONGODB_URI=mongodb://${mongodb_username}:${mongodb_password}@${mongodb_private_ip}:27017/meanapp
EOF

chown -R $APP_USER:$APP_USER $APP_DIR
cd $APP_DIR && sudo -u $APP_USER npm install

# Nginx config
cat >/etc/nginx/conf.d/mean-app.conf <<'NGINXEOF'
upstream nodejs_backend { server 127.0.0.1:3000; }
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://nodejs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

# Systemd service
cat >/etc/systemd/system/mean-app.service <<EOF
[Unit]
Description=MEAN Stack App
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# CloudWatch config
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/mean-setup.log",
            "log_group_name": "/aws/ec2/${project_name}-${environment}",
            "log_stream_name": "{instance_id}/setup.log"
          }
        ]
      }
    }
  }
}
EOF

# Start services
systemctl daemon-reload
systemctl enable nginx mean-app amazon-cloudwatch-agent
systemctl start nginx mean-app amazon-cloudwatch-agent

sleep 5
curl -f http://localhost:3000/api/health && log "✅ App OK" || log "❌ App failed"
log "=== Setup completed ==="
