# MetalCraft

<p align="center">
  <img width="1254" height="1254" alt="MetalCraft App Icon" src="https://github.com/user-attachments/assets/bdd586e4-1b2f-4fc2-9d29-c8afd54c7591" />
</p>

<h1 align="center">MetalCraft</h1>

<h3 align="center">AI Directs. Metal Crafts.</h3>

<p align="center">
  An agentic AI-powered media production system combining Google Gemini,
  Parallel AI, Apple Metal GPU, native iOS, and a cloud control plane.
</p>

<p align="center">

  <img src="https://img.shields.io/badge/AI-Google%20Gemini-4285F4?style=for-the-badge" alt="Google Gemini">

  <img src="https://img.shields.io/badge/Research-Parallel%20AI-111111?style=for-the-badge" alt="Parallel AI">

  <img src="https://img.shields.io/badge/iOS-Swift%20%7C%20SwiftUI-F05138?style=for-the-badge" alt="Swift">

  <img src="https://img.shields.io/badge/GPU-Apple%20Metal-000000?style=for-the-badge" alt="Apple Metal">

  <img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge" alt="FastAPI">

  <img src="https://img.shields.io/badge/Deployment-Render-46E3B7?style=for-the-badge" alt="Render">

  <img src="https://img.shields.io/badge/Observability-Grafana-F46800?style=for-the-badge" alt="Grafana">

  <img src="https://img.shields.io/badge/Container-Docker-2496ED?style=for-the-badge" alt="Docker">

</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#why-metalcraft">Why MetalCraft</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#agentic-pipeline">Agentic Pipeline</a> •
  <a href="#ios-application">iOS Application</a> •
  <a href="#cloud-control-plane">Cloud Control Plane</a> •
  <a href="#technology-stack">Tech Stack</a> •
  <a href="#deployment">Deployment</a>
</p>

---

## 🌐 Live Project

**Website:**  
[MetalCraft Cloud Control Plane](https://metalcraft-olso.onrender.com)

**Project Repository:**  
[GitHub Repository](https://github.com/sohamgosavi2006/MetalCraft)

---

# 📸 Project Preview

## Web Cloud Control Plane

<p align="center">
  <img
    src="docs/images/website-preview.png"
    alt="MetalCraft Web Cloud Control Plane"
    width="100%"
  >
</p>

> <img width="1440" height="864" alt="Website iPhone Simulator" src="https://github.com/user-attachments/assets/5f7eb8c6-1f3a-44a6-b4c4-2eca96c7a6ff" />

---

## 📱 MetalCraft iOS Application

<p align="center">
  <img
    src="docs/images/iphone-app-preview.png"
    alt="MetalCraft iOS Application"
    width="320"
  >
</p>

> <img width="414" height="896" alt="Video Generated " src="https://github.com/user-attachments/assets/9fdf4b5d-1b53-413d-8016-436248497241" />

---

# Overview

**MetalCraft** is an **agentic AI-powered media production system** designed around one core idea:

> ## AI Directs. Metal Crafts.

MetalCraft combines **cloud-based AI intelligence** with **native iOS GPU execution**.

Instead of treating AI as simply a chatbot or an editing assistant, MetalCraft uses AI as a **creative director** that understands the user's intent, researches context, produces a structured production plan, and orchestrates execution on Apple hardware.

The cloud handles:

- Creative reasoning
- Context research
- Edit planning
- Pipeline orchestration
- Device management
- Job dispatch
- Telemetry
- Audit information

The iPhone handles:

- Local media access
- Image processing
- Video processing
- GPU effects
- Color grading
- Timeline composition
- Audio synchronization
- Final rendering

The architecture can be summarized as:

```text
                USER
                  │
                  ▼
       ┌──────────────────────┐
       │ MetalCraft Web       │
       │ Cloud Control Plane  │
       └──────────┬───────────┘
                  │
                  ▼
       ┌──────────────────────┐
       │    Agentic AI Layer  │
       │                      │
       │ Gemini + Parallel    │
       └──────────┬───────────┘
                  │
                  ▼
       ┌──────────────────────┐
       │ Structured EditPlan  │
       │        JSON          │
       └──────────┬───────────┘
                  │
                 WSS
                  │
                  ▼
       ┌──────────────────────┐
       │    MetalCraft iOS    │
       │       Application    │
       └──────────┬───────────┘
                  │
                  ▼
       ┌──────────────────────┐
       │    Apple Metal GPU   │
       │    + AVFoundation    │
       └──────────┬───────────┘
                  │
                  ▼
              FINAL MEDIA
