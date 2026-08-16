/**
 * MetalCraft Web Companion Client Application
 * Connects to Render FastAPI backend via HTTPS and WebSockets.
 */

let activePlan = null;
let currentGenerationId = null;
let webSocket = null;

document.addEventListener("DOMContentLoaded", () => {
    initTabs();
    initChips();
    initAIStudio();
    initWebSocket();
    fetchBackendHealth();
    fetchJobs();
    fetchAnalytics();
    fetchAuditLogs();

    // Auto-refresh periodic data every 10 seconds
    setInterval(() => {
        fetchBackendHealth();
        fetchAnalytics();
    }, 10000);
});

// MARK: - Navigation Tabs
function initTabs() {
    const navButtons = document.querySelectorAll(".nav-btn");
    navButtons.forEach(btn => {
        btn.addEventListener("click", () => {
            navButtons.forEach(b => b.classList.remove("active"));
            document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));
            btn.classList.add("active");
            const tabId = btn.getAttribute("data-tab");
            const targetPane = document.getElementById(`pane-${tabId}`);
            if (targetPane) targetPane.classList.add("active");

            if (tabId === "pipeline") fetchJobs();
            if (tabId === "analytics") fetchAnalytics();
            if (tabId === "audit") fetchAuditLogs();
        });
    });
}

// MARK: - Quick Chips
function initChips() {
    document.querySelectorAll(".chip").forEach(chip => {
        chip.addEventListener("click", () => {
            const promptText = chip.getAttribute("data-prompt");
            const promptInput = document.getElementById("prompt-input");
            promptInput.value = promptText;
            promptInput.focus();
        });
    });
}

// MARK: - AI Create Studio Logic
function initAIStudio() {
    const btnFormulate = document.getElementById("btn-formulate-plan");
    const btnDispatch = document.getElementById("btn-dispatch-job");
    const btnCopy = document.getElementById("btn-copy-plan");
    const promptInput = document.getElementById("prompt-input");
    const aspectSelect = document.getElementById("aspect-ratio-select");

    btnFormulate.addEventListener("click", async () => {
        const prompt = promptInput.value.trim();
        if (!prompt) {
            alert("Please enter a creative prompt first.");
            return;
        }

        btnFormulate.disabled = true;
        btnFormulate.innerHTML = "Thinking...";
        setAgentFeed("Gemini 2.5 Flash analyzing prompt and synthesizing cinematography parameters...");

        try {
            const resp = await fetch("/api/v1/agent/create", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    prompt: prompt,
                    mediaMetadata: {
                        type: "video",
                        aspectRatio: aspectSelect.value,
                        assets: [
                            { id: "media_001", name: "Product Hero Shot", type: "image", width: 1080, height: 1920 },
                            { id: "media_002", name: "Product Macro Detail", type: "image", width: 1080, height: 1920 },
                            { id: "media_003", name: "Product Lifestyle Use", type: "image", width: 1080, height: 1920 }
                        ]
                    }
                })
            });

            const data = await resp.json();
            if (data.editPlan) {
                activePlan = data.editPlan;
                displayPlan(activePlan);
                setAgentFeed(`✓ Gemini Creative Director formulated plan: "${data.reasoning || 'Cinematic reel synthesized'}"`);

                if (data.researchContext) {
                    const rCard = document.getElementById("research-card");
                    document.getElementById("research-summary-text").textContent = data.researchContext;
                    rCard.style.display = "block";
                }

                btnDispatch.disabled = false;
            } else {
                setAgentFeed(`Error formulating plan: ${data.error || 'Unknown error'}`);
            }
        } catch (err) {
            setAgentFeed(`Connection error: ${err.message}`);
        } finally {
            btnFormulate.disabled = false;
            btnFormulate.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg> Formulate EditPlan`;
        }
    });

    btnDispatch.addEventListener("click", async () => {
        if (!activePlan) return;
        btnDispatch.disabled = true;
        btnDispatch.innerHTML = "Dispatching...";

        try {
            const resp = await fetch("/api/v1/generations", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    plan: activePlan,
                    projectName: "MetalCraft Showcase Reel"
                })
            });

            const data = await resp.json();
            currentGenerationId = data.generationId;

            // Switch to pipeline tab to observe live execution
            document.getElementById("tab-pipeline").click();
            updatePipelineStatus("JOB_DISPATCHED", "Job Dispatched to iPhone", 0.05, 0, 450);
        } catch (err) {
            alert(`Failed to dispatch job: ${err.message}`);
        } finally {
            btnDispatch.disabled = false;
            btnDispatch.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg> Dispatch to iPhone GPU`;
        }
    });

    btnCopy.addEventListener("click", () => {
        if (activePlan) {
            navigator.clipboard.writeText(JSON.stringify(activePlan, null, 2));
            btnCopy.textContent = "Copied!";
            setTimeout(() => { btnCopy.textContent = "Copy JSON"; }, 2000);
        }
    });
}

function setAgentFeed(text) {
    const feed = document.getElementById("agent-feed-box");
    feed.innerHTML = `<div class="feed-entry">${text}</div>`;
}

function displayPlan(plan) {
    const display = document.getElementById("plan-json-display");
    display.textContent = JSON.stringify(plan, null, 2);

    const scenesCount = plan.scenes ? plan.scenes.length : 1;
    const duration = plan.targetDuration || 15.0;
    const audioTitle = plan.audioPlan ? plan.audioPlan.trackTitle || plan.audioPlan.mood : "None";

    document.getElementById("stat-scenes").textContent = scenesCount;
    document.getElementById("stat-duration").textContent = `${duration.toFixed(1)}s`;
    document.getElementById("stat-audio").textContent = audioTitle;
}

// MARK: - Real-Time WebSocket Connection
function initWebSocket() {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsUrl = `${protocol}//${window.location.host}/ws/web`;

    try {
        webSocket = new WebSocket(wsUrl);

        webSocket.onopen = () => {
            console.log("[WebSocket] Connected to MetalCraft Cloud Hub");
        };

        webSocket.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                handleWebSocketMessage(msg);
            } catch (e) {
                console.warn("[WebSocket] Could not parse message", event.data);
            }
        };

        webSocket.onclose = () => {
            console.log("[WebSocket] Disconnected. Reconnecting in 3s...");
            setTimeout(initWebSocket, 3000);
        };
    } catch (e) {
        console.error("[WebSocket] Connection error", e);
    }
}

function handleWebSocketMessage(msg) {
    const type = msg.type;

    if (type === "CONNECTION_ESTABLISHED" || type === "DEVICE_STATUS_CHANGED" || type === "DEVICE_REGISTERED") {
        updateDeviceStatus(msg.isIosConnected || msg.status === "online");
    } else if (type === "GENERATION_PROGRESS") {
        const progress = msg.progress || 0.0;
        const currentFrame = msg.currentFrame || 0;
        const totalFrames = msg.totalFrames || 0;
        const stage = msg.stage || "METAL_RENDERING";
        const message = msg.progressMessage || "Rendering on Apple Metal GPU";
        currentGenerationId = msg.generationId || currentGenerationId;

        updatePipelineStatus(stage, message, progress, currentFrame, totalFrames);
    } else if (type === "GENERATION_COMPLETED") {
        updatePipelineStatus("COMPLETED", "Video Artifact Created & Validated", 1.0, 450, 450);
        fetchJobs();
        fetchAuditLogs();
    } else if (type === "TELEMETRY_LOG") {
        appendTelemetryLog(msg.event);
    }
}

// MARK: - Pipeline Status Updates
function updatePipelineStatus(stage, message, progress, currentFrame, totalFrames) {
    document.getElementById("pipeline-status-text").textContent = message;
    const percent = Math.round(progress * 100);
    document.getElementById("pipeline-percent-text").textContent = `${percent}%`;
    document.getElementById("pipeline-progress-fill").style.width = `${percent}%`;

    document.getElementById("pipe-current-frame").textContent = currentFrame;
    document.getElementById("pipe-total-frame").textContent = totalFrames;
    document.getElementById("pipe-current-stage").textContent = stage;
    document.getElementById("pipe-correlation-id").textContent = currentGenerationId || "None";

    // Highlight flowchart nodes
    const stages = ["user-request", "gemini", "parallel", "editplan", "device-dispatch", "metal", "avfoundation", "artifact"];
    stages.forEach(s => {
        const el = document.getElementById(`stage-${s}`);
        if (el) el.classList.remove("node-active", "node-complete");
    });

    if (stage === "PLANNING") {
        highlightStage("gemini");
    } else if (stage === "WAITING_FOR_DEVICE" || stage === "JOB_DISPATCHED") {
        highlightStage("device-dispatch");
    } else if (stage === "METAL_RENDERING" || stage === "RENDERING") {
        highlightStage("metal");
    } else if (stage === "AVFOUNDATION" || stage === "EXPORTING") {
        highlightStage("avfoundation");
    } else if (stage === "COMPLETED" || stage === "PREVIEW_READY") {
        highlightStage("artifact");
    }
}

function highlightStage(stageName) {
    const el = document.getElementById(`stage-${stageName}`);
    if (el) el.classList.add("node-active");
}

function updateDeviceStatus(isOnline) {
    const dot = document.getElementById("device-dot");
    const label = document.getElementById("device-label");

    if (isOnline) {
        dot.className = "device-dot dot-online";
        label.textContent = "MetalCraft iPhone ● Connected";
    } else {
        dot.className = "device-dot dot-waiting";
        label.textContent = "Waiting for iPhone...";
    }
}

// MARK: - Data Fetchers
async function fetchBackendHealth() {
    try {
        const resp = await fetch("/api/v1/health");
        const data = await resp.json();
        if (data.devices && data.devices.connectedCount > 0) {
            updateDeviceStatus(true);
        }
    } catch (e) {}
}

async function fetchJobs() {
    try {
        const resp = await fetch("/api/v1/generations");
        const data = await resp.json();
        const tbody = document.getElementById("jobs-tbody");
        if (!data.generations || data.generations.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-muted">No generation jobs found. Create one in AI Create!</td></tr>`;
            return;
        }

        tbody.innerHTML = data.generations.map(j => `
            <tr>
                <td><code>${j.generationId}</code></td>
                <td>${j.projectName || 'Cinematic Reel'}</td>
                <td><span class="status-tag ${j.status === 'COMPLETED' ? 'success' : 'running'}">${j.status}</span></td>
                <td>${Math.round((j.progress || 0) * 100)}%</td>
                <td>${j.renderDurationSec ? `${j.renderDurationSec.toFixed(1)}s` : '—'}</td>
                <td>${j.createdAt ? new Date(j.createdAt).toLocaleTimeString() : '—'}</td>
            </tr>
        `).join("");
    } catch (e) {}
}

async function fetchAnalytics() {
    try {
        const resp = await fetch("/api/v1/analytics");
        const data = await resp.json();
        if (data.observability) {
            document.getElementById("metric-gpu-time").textContent = `${data.observability.averageGpuTimeMs} ms`;
            document.getElementById("metric-fps").textContent = `${data.observability.averageFps} FPS`;
            document.getElementById("metric-events-count").textContent = data.observability.totalEventsLogged || 0;
        }
    } catch (e) {}
}

async function fetchAuditLogs() {
    try {
        const resp = await fetch("/api/v1/audit?limit=25");
        const data = await resp.json();
        const tbody = document.getElementById("audit-tbody");
        if (!data.auditRecords || data.auditRecords.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-muted">No audit events recorded yet.</td></tr>`;
            return;
        }

        tbody.innerHTML = data.auditRecords.map(r => `
            <tr>
                <td>${r.timestamp ? new Date(r.timestamp).toLocaleTimeString() : '—'}</td>
                <td><span class="status-tag">${r.category}</span></td>
                <td><strong>${r.action}</strong></td>
                <td><span class="status-tag ${r.status === 'SUCCESS' ? 'success' : 'waiting'}">${r.status}</span></td>
                <td><code>${r.generationId || '—'}</code></td>
                <td>${r.description}</td>
            </tr>
        `).join("");
    } catch (e) {}
}

function appendTelemetryLog(event) {
    const box = document.getElementById("telemetry-log-box");
    const entry = document.createElement("div");
    entry.className = "log-entry";
    const time = new Date().toLocaleTimeString();
    entry.innerHTML = `[${time}] <strong>${event.eventType || 'EVENT'}</strong> — ${event.operation || ''} (GPU: ${event.gpuTimeMs ? `${event.gpuTimeMs}ms` : '—'})`;
    box.prepend(entry);
}
