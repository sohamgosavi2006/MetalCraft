# Google Cloud Architecture

## Services Used

| Service | Purpose | Configuration |
|---------|---------|--------------|
| Cloud Run | Host the ADK agent endpoint | Python, Flask/FastAPI, single service |
| Secret Manager | Store API keys (Gemini, Grafana, Parallel) | 3 secrets |
| IAM | Service account with least privilege | Custom role |
| Vertex AI API | Gemini model access | gemini-2.0-flash |

## Cloud Run Configuration

```yaml
# cloudbuild.yaml / service.yaml
service:
  name: metalcraft-agent
  region: us-central1
  container:
    image: gcr.io/PROJECT_ID/metalcraft-agent:latest
    port: 8080
    env:
      - PROJECT_ID
    resources:
      cpu: 1
      memory: 512Mi
    timeout: 60s
    concurrency: 10
    minInstances: 0
    maxInstances: 5
```

## API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/agent/create` | Submit creative prompt → receive EditPlan |
| POST | `/api/v1/telemetry` | Receive telemetry events from iOS |
| GET | `/health` | Health check |

## Agent Deployment

```
cloud/
├── Dockerfile
├── requirements.txt
├── main.py                    # Flask/FastAPI entry
├── agent/
│   ├── agent.py              # ADK agent definition
│   ├── prompts.py            # System prompts
│   ├── tools.py              # Tool implementations
│   ├── tools_grafana.py      # Grafana MCP tool
│   ├── tools_parallel.py     # Parallel MCP tool
│   └── schemas.py            # JSON schemas
├── mcp/
│   ├── grafana_client.py     # Grafana MCP client
│   └── parallel_client.py    # Parallel MCP client
└── deploy/
    ├── cloudbuild.yaml
    └── service.yaml
```

## requirements.txt

```
google-adk>=0.1.0
google-cloud-aiplatform>=1.40.0
google-cloud-secret-manager>=2.16.0
flask>=3.0.0
gunicorn>=21.2.0
requests>=2.31.0
```

## Secret Manager Keys

```
projects/PROJECT_ID/secrets/gemini-api-key/versions/latest
projects/PROJECT_ID/secrets/grafana-api-key/versions/latest
projects/PROJECT_ID/secrets/parallel-api-key/versions/latest
```

## Cost Estimation

| Service | Estimated Monthly Cost | Notes |
|---------|----------------------|-------|
| Cloud Run | $0-5 | Scale to zero, low traffic |
| Secret Manager | $0.06 | 3 secrets, low access |
| Vertex AI (Gemini) | $5-20 | Per-token pricing |
| Total | ~$5-25/month | Development usage |
