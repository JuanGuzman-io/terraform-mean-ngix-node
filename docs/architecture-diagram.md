# Diagrama de Arquitectura MEAN Stack en AWS

## Diagrama de Red y Componentes

```
                                    INTERNET
                                        |
                              [Internet Gateway]
                                        |
    ╔══════════════════════════════════════════════════════════════════╗
    ║                      VPC: 10.0.0.0/16                           ║
    ║                                                                  ║
    ║    Public Subnet A        │        Public Subnet B              ║
    ║    10.0.1.0/24           │        10.0.2.0/24                  ║
    ║    (us-east-1a)          │        (us-east-1b)                 ║
    ║                          │                                      ║
    ║  [ALB Primary]   [NAT Gateway]     [ALB Secondary]              ║
    ║  Load Balancer      │              Load Balancer               ║
    ║       │             │                    │                     ║
    ║       │        [Elastic IP]              │                     ║
    ║       │             │                    │                     ║
    ║ ──────┼─────────────┼────────────────────┼─────────────────    ║
    ║       │             │                    │                     ║
    ║   Private Subnet A  │         Private Subnet B                 ║
    ║   10.0.3.0/24       │         10.0.4.0/24                     ║
    ║   (us-east-1a)      │         (us-east-1b)                    ║
    ║                     │                                          ║
    ║  [EC2 Web Server]   │         [EC2 MongoDB]                   ║
    ║  - Nginx (80)       │         - MongoDB (27017)               ║
    ║  - Node.js (3000)   │         - EBS Volume (50GB)             ║
    ║  - SSH (22)         │         - SSH (22)                      ║
    ║         │           │                │                        ║
    ║         └───────── MongoDB ─────────┘                        ║
    ║                   Connection                                   ║
    ╚══════════════════════════════════════════════════════════════════╝
                                        │
                              [CloudWatch Monitoring]
                              [SNS Notifications]
```

## Flujo de Tráfico

### 1. Tráfico de Usuario
```
Usuario → Internet → ALB → Nginx (Puerto 80) → Node.js (Puerto 3000) → MongoDB (Puerto 27017)
```

### 2. Health Checks
```
ALB → Health Check (/) → Nginx → Node.js → MongoDB → Respuesta de estado
```

### 3. Tráfico Saliente (Actualizaciones)
```
MongoDB → NAT Gateway → Internet Gateway → Internet
Web Server → NAT Gateway → Internet Gateway → Internet
```

## Security Groups Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ALB-SG        │    │   WEB-SG        │    │   DB-SG         │
│                 │    │                 │    │                 │
│ IN: 80,443/0.0  │───▶│ IN: 80,3000/ALB │───▶│ IN: 27017/WEB   │
│ OUT: 80,3000/VPC│    │ IN: 22/VPC      │    │ IN: 22/VPC      │
│                 │    │ OUT: ALL        │    │ OUT: 80,443,53  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Componentes Técnicos

### VPC Configuration
- **CIDR**: 10.0.0.0/16
- **DNS Resolution**: Enabled
- **DNS Hostnames**: Enabled
- **Tenancy**: Default

### Subnets
| Tipo | CIDR | AZ | Propósito |
|------|------|----|-----------| 
| Pública | 10.0.1.0/24 | us-east-1a | ALB, NAT Gateway |
| Pública | 10.0.2.0/24 | us-east-1b | ALB Secondary |
| Privada | 10.0.3.0/24 | us-east-1a | Web Server |
| Privada | 10.0.4.0/24 | us-east-1b | MongoDB |

### Route Tables
| Tabla | Destino | Target |
|-------|---------|--------|
| Public RT | 0.0.0.0/0 | Internet Gateway |
| Private RT-1 | 0.0.0.0/0 | NAT Gateway |
| Private RT-2 | 0.0.0.0/0 | NAT Gateway |

### Application Load Balancer
- **Scheme**: internet-facing
- **Type**: application
- **Subnets**: Public subnets (Multi-AZ)
- **Security Groups**: ALB-SG
- **Listeners**: HTTP (80), HTTPS (443) opcional

### Target Groups
| Nombre | Puerto | Health Check |
|--------|--------|--------------|
| web-tg | 80 | GET / → 200 |
| api-tg | 3000 | GET /api/health → 200 |

### EC2 Instances
| Instancia | Tipo | AMI | Subred | Propósito |
|-----------|------|-----|--------|-----------|
| Web Server | t2.micro | Amazon Linux 2023 | Private-A | Nginx + Node.js |
| DB Server | t2.micro | Amazon Linux 2023 | Private-B | MongoDB |

### Storage
| Volumen | Tipo | Tamaño | Cifrado | Propósito |
|---------|------|--------|---------|-----------|
| Root (Web) | gp3 | 20GB | ✅ | Sistema Web |
| Root (DB) | gp3 | 20GB | ✅ | Sistema DB |
| Data (DB) | gp3 | 50GB | ✅ | Datos MongoDB |

### NAT Gateway
- **Type**: NAT Gateway
- **Subnet**: Public subnet us-east-1a
- **Elastic IP**: Allocated
- **Bandwidth**: Up to 45 Gbps

### Monitoring
- **CloudWatch Logs**: EC2 instances, ALB
- **CloudWatch Metrics**: CPU, Memory, Disk, Network
- **Alarms**: Response time, Unhealthy targets
- **Log Retention**: 7 days (configurable)

## Características de Seguridad

### Network Security
- ✅ **Private Subnets**: Instancias no accesibles directamente
- ✅ **Security Groups**: Reglas restrictivas por capas
- ✅ **Network ACLs**: Protección adicional a nivel de subred
- ✅ **NAT Gateway**: Acceso saliente controlado

### Data Security
- ✅ **EBS Encryption**: Todos los volúmenes cifrados
- ✅ **MongoDB SSL**: Comunicación cifrada
- ✅ **IAM Roles**: Permisos mínimos necesarios
- ✅ **Secrets Management**: Credenciales como variables sensibles

### Access Security
- ✅ **SSH Key Pairs**: Acceso basado en llaves
- ✅ **Bastion Pattern**: Acceso SSH a través de jump box
- ✅ **IMDSv2**: Metadata service security hardening
- ✅ **Security Headers**: Nginx configurado con headers seguros

## High Availability

### Multi-AZ Design
- ✅ **ALB**: Desplegado en múltiples zonas
- ✅ **Subnets**: Distribuidas en 2+ AZs
- ✅ **NAT Gateway**: Puede expandirse a Multi-AZ
- ✅ **EBS**: Respaldo automático dentro de AZ

### Scalability Ready
- ✅ **Target Groups**: Preparados para múltiples instancias
- ✅ **Auto Scaling**: Puede agregarse fácilmente
- ✅ **Load Balancer**: Soporta múltiples targets
- ✅ **Database**: Puede convertirse a replica set

## Performance Optimization

### Network Performance
- ✅ **Enhanced Networking**: Habilitado en instancias
- ✅ **Placement Groups**: Puede agregarse para latencia
- ✅ **EBS Optimized**: Instancias optimizadas para storage
- ✅ **GP3 Volumes**: Performance baseline garantizado

### Application Performance
- ✅ **Nginx Caching**: Headers y compresión configurados
- ✅ **Node.js Clustering**: Preparado para múltiples workers
- ✅ **MongoDB Indexes**: Configuración optimizada
- ✅ **CloudWatch**: Métricas para optimización continua

---

**Diagrama creado para TechOps Solutions - FinTech Solutions S.A.**  
**Actividad: Despliegue MEAN Stack con Terraform**  
**Fecha: Junio 2025**
