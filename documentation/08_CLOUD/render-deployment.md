# MetalCraft — Render Production Deployment Guide

## 1. Blueprint Deployment with `render.yaml`
MetalCraft is pre-configured with a root `render.yaml` Infrastructure as Code blueprint for 1-click deployment to Render.

---

## 2. Environment Variables Configuration
Set the following environment variables in the Render Service Dashboard:

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `ENVIRONMENT` | Deployment stage | `production` |
| `PORT` | Listening port on Render | `8080` (auto-assigned by Render) |
| `GEMINI_API_KEY` | Google Gemini 2.5 Flash API Key | `AIzaSy...` |
| `PARALLEL_API_KEY` | Parallel Search API Key | `sk-parallel-...` |
| `GRAFANA_URL` | Grafana Cloud Instance URL | `https://your-instance.grafana.net` |
| `GRAFANA_TOKEN` | Grafana Service Account Token | `glsa_...` |
| `DATABASE_URL` | Persistent SQLite database path | `sqlite+aiosqlite:///./metalcraft_state.db` |
| `IOS_AUTH_SECRET` | HMAC Secret for Device Registration | Auto-generated |
| `CORS_ALLOWED_ORIGINS`| Allowed Web Origins | `https://metalcraft.onrender.com,*` |

---

## 3. Health Check Path
- **Health Probe**: `/api/v1/health`
- Verifies server responsiveness, SQLite database connection, and connectivity with Gemini, Parallel, and Grafana.
