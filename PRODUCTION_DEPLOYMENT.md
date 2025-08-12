# Production Deployment Guide for LiveKit AI Agent

## Overview

Your LiveKit AI agent is now configured for production deployment with a custom token server. This guide walks you through deploying both the agent and token server to production.

## What We've Set Up

### 1. Production Token Server (`livekit-agent/server.py`)

- Flask-based token server with production-ready features
- Health check endpoint at `/health`
- Token generation endpoint at `/token`
- CORS support for web clients
- Proper error handling and logging
- Environment variable configuration

### 2. Updated Flutter Token Service

- Production server support with automatic fallback
- Environment variable configuration
- Proper error handling with fallback mechanisms

### 3. Docker Configuration

- Multi-service Docker setup (agent + token server)
- Configurable startup script
- Production-ready Dockerfile with security best practices

## Deployment Steps

### Step 1: Choose Your Deployment Platform

**Recommended Options:**

1. **AWS ECS/EKS** - Best for scalability
2. **Google Cloud Run** - Easiest for containerized apps
3. **DigitalOcean App Platform** - Good balance of features and cost
4. **Railway/Render** - Simple deployment for smaller scale

### Step 2: Environment Variables Configuration

Set these environment variables in your production environment:

```bash
# LiveKit Configuration
LIVEKIT_API_KEY=your_api_key_here
LIVEKIT_API_SECRET=your_api_secret_here
LIVEKIT_URL=wss://your-livekit-server.com

# OpenAI Configuration (for the AI agent)
OPENAI_API_KEY=your_openai_key_here

# Flask Configuration
FLASK_ENV=production
PORT=8080

# Service Configuration (optional)
SERVICE=both  # Options: both, token-server, agent
```

### Step 3: Update Flutter Environment for Production

Update your `flutter-demo/.env`:

```
PRODUCTION_TOKEN_SERVER_URL=https://your-deployed-domain.com
```

### Step 4: Deploy with Docker

#### Option A: Single Container (Both Services)

```bash
# Build the image
docker build -t your-registry/livekit-agent:latest .

# Run locally to test
docker run -p 8080:8080 -p 8081:8081 \
  -e LIVEKIT_API_KEY=your_key \
  -e LIVEKIT_API_SECRET=your_secret \
  -e LIVEKIT_URL=wss://your-server.com \
  -e OPENAI_API_KEY=your_openai_key \
  your-registry/livekit-agent:latest

# Push to registry
docker push your-registry/livekit-agent:latest
```

#### Option B: Separate Services

```bash
# Token server only
docker run -p 8080:8080 \
  -e SERVICE=token-server \
  -e LIVEKIT_API_KEY=your_key \
  -e LIVEKIT_API_SECRET=your_secret \
  -e LIVEKIT_URL=wss://your-server.com \
  your-registry/livekit-agent:latest

# Agent only
docker run -p 8081:8081 \
  -e SERVICE=agent \
  -e LIVEKIT_API_KEY=your_key \
  -e LIVEKIT_API_SECRET=your_secret \
  -e LIVEKIT_URL=wss://your-server.com \
  -e OPENAI_API_KEY=your_openai_key \
  your-registry/livekit-agent:latest
```

### Step 5: Kubernetes Deployment (Recommended for Production)

Create these Kubernetes manifests:

#### secrets.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: livekit-secrets
type: Opaque
stringData:
  LIVEKIT_API_KEY: "your_api_key"
  LIVEKIT_API_SECRET: "your_api_secret"
  LIVEKIT_URL: "wss://your-livekit-server.com"
  OPENAI_API_KEY: "your_openai_key"
```

#### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: livekit-agent
spec:
  replicas: 3
  selector:
    matchLabels:
      app: livekit-agent
  template:
    metadata:
      labels:
        app: livekit-agent
    spec:
      containers:
        - name: agent
          image: your-registry/livekit-agent:latest
          ports:
            - containerPort: 8080
            - containerPort: 8081
          envFrom:
            - secretRef:
                name: livekit-secrets
          env:
            - name: SERVICE
              value: "both"
            - name: FLASK_ENV
              value: "production"
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: livekit-agent-service
spec:
  selector:
    app: livekit-agent
  ports:
    - name: token-server
      port: 80
      targetPort: 8080
    - name: agent-health
      port: 8081
      targetPort: 8081
  type: LoadBalancer
```

#### ingress.yaml (for HTTPS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: livekit-agent-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - your-domain.com
      secretName: livekit-agent-tls
  rules:
    - host: your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: livekit-agent-service
                port:
                  number: 80
```

### Step 6: Cloud Platform Specific Instructions

#### AWS ECS

1. Create an ECS cluster
2. Create a task definition using your Docker image
3. Set up Application Load Balancer
4. Configure Route 53 for your domain

#### Google Cloud Run

```bash
# Deploy to Cloud Run
gcloud run deploy livekit-agent \
  --image=your-registry/livekit-agent:latest \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --port=8080 \
  --set-env-vars="LIVEKIT_API_KEY=your_key,LIVEKIT_API_SECRET=your_secret"
```

#### DigitalOcean App Platform

Create `app.yaml`:

```yaml
name: livekit-agent
services:
  - name: agent
    source_dir: /
    github:
      repo: your-username/your-repo
      branch: main
    run_command: ./start.sh
    environment_slug: docker
    instance_count: 1
    instance_size_slug: basic-xxs
    http_port: 8080
    routes:
      - path: /
    envs:
      - key: LIVEKIT_API_KEY
        value: your_key
      - key: LIVEKIT_API_SECRET
        value: your_secret
      - key: LIVEKIT_URL
        value: wss://your-server.com
```

## Testing Your Production Deployment

### 1. Health Check

```bash
curl https://your-domain.com/health
```

### 2. Token Generation Test

```bash
curl -X POST https://your-domain.com/token \
  -H "Content-Type: application/json" \
  -d '{"roomName": "test-room", "participantName": "test-user"}'
```

### 3. Flutter App Testing

Update your Flutter app's environment:

```
PRODUCTION_TOKEN_SERVER_URL=https://your-domain.com
```

## Production Best Practices

### Security

- [ ] Use HTTPS/TLS for all endpoints
- [ ] Store secrets in secure secret management (AWS Secrets Manager, etc.)
- [ ] Enable CORS only for your domains
- [ ] Use API rate limiting
- [ ] Implement authentication for sensitive endpoints

### Monitoring

- [ ] Set up health checks and uptime monitoring
- [ ] Configure log aggregation (ELK stack, CloudWatch, etc.)
- [ ] Set up metrics collection (Prometheus, CloudWatch)
- [ ] Configure alerting for failures

### Scaling

- [ ] Use horizontal pod autoscaler in Kubernetes
- [ ] Configure load balancing
- [ ] Set appropriate resource limits
- [ ] Monitor and tune performance

### Reliability

- [ ] Set up automated backups if using databases
- [ ] Implement graceful shutdown handling
- [ ] Use rolling deployments
- [ ] Set up disaster recovery procedures

## Troubleshooting

### Common Issues

1. **Token server not accessible**: Check firewall rules and load balancer configuration
2. **CORS errors**: Ensure CORS is configured for your Flutter app's domain
3. **Token validation errors**: Verify LIVEKIT_API_KEY and LIVEKIT_API_SECRET are correct
4. **Agent connection issues**: Check LIVEKIT_URL and network connectivity

### Debugging Commands

```bash
# Check pod logs
kubectl logs -f deployment/livekit-agent

# Test token server locally
python test_server.py

# Check environment variables
kubectl exec -it deployment/livekit-agent -- env | grep LIVEKIT
```

## Next Steps

1. **Deploy to staging first** - Test everything in a staging environment
2. **Set up CI/CD** - Automate deployments with GitHub Actions or similar
3. **Monitor performance** - Set up comprehensive monitoring
4. **Plan for scaling** - Consider auto-scaling based on load
5. **Security audit** - Review and harden security configurations

Your LiveKit AI agent is now production-ready! 🚀
