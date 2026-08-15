# iPhone ↔ Mac Local Agent Networking & Auto-Discovery Guide

## 1. Overview

This document details the local networking architecture connecting the physical iPhone running MetalCraft to the local agent backend running on the Mac development host.

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Physical iPhone 11                       │
│  - MetalCraft App                                           │
│  - AgentService with Multi-Candidate Auto-Discovery         │
│  - NSLocalNetworkUsageDescription + NSBonjourServices       │
│  - NSAppTransportSecurity (NSAllowsLocalNetworking: true)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               │ Local Area Network / Personal Hotspot
                               │ (HTTP JSON-RPC / REST)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       MacBook Host                          │
│  - Backend Host: 0.0.0.0 (All Interfaces)                   │
│  - Port: 8080                                               │
│  - Bonjour Zeroconf: _metalcraft._tcp on port 8080          │
│  - mDNS Hostname: admins-MacBook-Pro-8.local:8080           │
│  - Active IP Addresses:                                     │
│      • 172.20.10.4:8080 (iPhone Personal Hotspot)          │
│      • 10.3.12.210:8080 (Local Wi-Fi)                       │
│  - Backend: Flask Server (app.py)                           │
│  - Gemini Creative Director (gemini-2.5-flash)              │
│  - Parallel Research Integration                            │
│  - Grafana Observability Integration (localhost:3000)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Key Failure Points & Resolutions

| Issue | Root Cause | Fix Implemented |
|---|---|---|
| **Localhost Confusion** | `127.0.0.1` on iPhone targets the phone, not the Mac. | Configured multi-target candidate resolution (`172.20.10.4:8080`, `admins-MacBook-Pro-8.local:8080`, etc.). |
| **Interface Binding** | Server was bound to `127.0.0.1` only. | Updated `.env` to enforce `LOCAL_AGENT_HOST=0.0.0.0` listening on all interfaces. |
| **iOS Local Network Permission** | iOS 14+ blocks LAN discovery without declaration. | Added `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_metalcraft._tcp`) to `Info.plist`. |
| **Network Switching** | IP changes when switching Wi-Fi / Hotspot. | Implemented parallel auto-discovery with fast health check probing (`/health`). |

---

## 4. Health Check Endpoint

- **Endpoint:** `GET /health`
- **Response Format:**
```json
{
  "hostname": "admins-MacBook-Pro-8.local",
  "service": "MetalCraft Agent Backend",
  "status": "healthy",
  "version": "1.0.0"
}
```

---

## 5. In-App User Controls

- **Connection Pill:** Displays real-time state (`● Connected`, `◌ Discovering Agent...`, `○ Disconnected`).
- **Auto-Discovery Button:** Tapping **"Auto-Discover Mac on Local Network"** tests all candidates simultaneously and locks onto the lowest latency active backend.
- **Preset Quick-Select:** One-tap switching between iPhone Hotspot, Bonjour Hostname, Wi-Fi LAN, and Simulator.
