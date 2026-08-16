/**
 * MetalCraft Web Companion Client
 * Controls the iPhone 17 Pro Simulator and connects to FastAPI Backend & WebSockets.
 */

let activePlan = null;
let currentGenerationId = null;
let webSocket = null;
let isRealDeviceConnected = false;

document.addEventListener("DOMContentLoaded", () => {
    initIOSTabs();
    initChips();
    initSimulatorActions();
    initWebSocket();
    fetchBackendHealth();
    fetchAnalytics();
    fetchAuditLogs();

    // Auto-refresh background health & metrics every 8 seconds
    setInterval(() => {
        fetchBackendHealth();
        fetchAnalytics();
        fetchAuditLogs();
    }, 8000);
});

// MARK: - iOS App Tab Switching inside Simulator
function initIOSTabs() {
    const tabButtons = document.querySelectorAll(".ios-tab-item");
    const views = document.querySelectorAll(".ios-view");
    const iosTitle = document.getElementById("ios-title");

    const titles = {
        "editor": "Editor",
        "ai-create": "AI Create",
        "analytics": "Analytics",
        "projects": "Projects"
    };

    tabButtons.forEach(btn => {
        btn.addEventListener("click", () => {
            const target = btn.getAttribute("data-target");
            tabButtons.forEach(b => b.classList.remove("active"));
            views.forEach(v => v.classList.remove("active"));

            btn.classList.add("active");
            const targetView = document.getElementById(`ios-view-${target}`);
            if (targetView) targetView.classList.add("active");

            if (iosTitle && titles[target]) {
                iosTitle.textContent = titles[target];
            }
        });
    });
}

// MARK: - Style Chips
function initChips() {
    document.querySelectorAll(".ios-chip").forEach(chip => {
        chip.addEventListener("click", () => {
            const prompt = chip.getAttribute("data-prompt");
            const input = document.getElementById("ios-prompt-input");
            if (input) {
                input.value = prompt;
                input.focus();
            }
        });
    });
}

// MARK: - Simulator Actions & Synthesis
function initSimulatorActions() {
    const btnSend = document.getElementById("btn-ios-synthesize");
    const btnCompSynth = document.getElementById("btn-companion-synthesize");
    const btnCompDispatch = document.getElementById("btn-companion-dispatch");
    const promptInput = document.getElementById("ios-prompt-input");

    async function triggerSynthesis() {
        const prompt = promptInput.value.trim();
        if (!prompt) return;

        setDynamicIsland("Thinking...", "pulse");
        highlightFlow("flow-gemini");
        setStepActive(1);
        addAssistantMessage(`Synthesizing cinematography parameters for: "${prompt}"...`);

        try {
            const resp = await fetch("/api/v1/agent/create", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    prompt: prompt,
                    mediaMetadata: {
                        type: "video",
                        aspectRatio: "9:16",
                        assets: [
                            { id: "media_001", name: "Hero Visual", type: "image", width: 1080, height: 1920 },
                            { id: "media_002", name: "Macro Detail", type: "image", width: 1080, height: 1920 },
                            { id: "media_003", name: "Scene Context", type: "image", width: 1080, height: 1920 }
                        ]
                    }
                })
            });

            const data = await resp.json();
            if (data.editPlan) {
                activePlan = data.editPlan;
                highlightFlow("flow-parallel");
                setStepActive(2);

                setTimeout(() => {
                    highlightFlow("flow-plan");
                    setStepActive(3);
                    renderPlanInPhone(activePlan);
                    addAssistantMessage(`✓ Formulated ${activePlan.scenes.length}-scene timeline (${activePlan.totalSceneDuration}s) with soundtrack '${activePlan.audioPlan?.trackTitle || 'Cinematic Flow'}'. Ready for Metal GPU execution.`);
                    setDynamicIsland("Plan Ready", "ready");

                    if (btnCompDispatch) {
                        btnCompDispatch.disabled = false;
                    }

                    // Auto-execute in browser simulator mode
                    simulateRenderingFlow(activePlan);
                }, 600);
            }
        } catch (err) {
            addAssistantMessage(`Error synthesizing plan: ${err.message}`);
            setDynamicIsland("Error", "error");
        }
    }

    if (btnSend) btnSend.addEventListener("click", triggerSynthesis);
    if (btnCompSynth) btnCompSynth.addEventListener("click", triggerSynthesis);

    if (promptInput) {
        promptInput.addEventListener("keydown", (e) => {
            if (e.key === "Enter") triggerSynthesis();
        });
    }

    // Dispatch to Real iPhone over WebSocket
    if (btnCompDispatch) {
        btnCompDispatch.addEventListener("click", async () => {
            if (!activePlan) return;
            addAssistantMessage("📡 Dispatching EditPlan command to connected iPhone via WebSocket...");
            setDynamicIsland("Dispatching...", "pulse");

            try {
                const resp = await fetch("/api/v1/generations", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        plan: activePlan,
                        projectName: "Cyberpunk Reel",
                        mediaMetadata: { type: "video" }
                    })
                });
                const job = await resp.json();
                currentGenerationId = job.generationId;
                addAssistantMessage(`🚀 Job ${job.generationId} queued. Streaming live Metal GPU progress...`);
            } catch (err) {
                addAssistantMessage(`Failed to dispatch job: ${err.message}`);
            }
        });
    }

    // Mode toggles
    const toggleSim = document.getElementById("toggle-mode-sim");
    const togglePhone = document.getElementById("toggle-mode-iphone");

    if (toggleSim && togglePhone) {
        toggleSim.addEventListener("click", () => {
            toggleSim.classList.add("active");
            togglePhone.classList.remove("active");
        });
        togglePhone.addEventListener("click", () => {
            togglePhone.classList.add("active");
            toggleSim.classList.remove("active");
        });
    }
}

// MARK: - Render Plan In Phone UI
function renderPlanInPhone(plan) {
    const planCard = document.getElementById("ios-plan-card");
    const durationLabel = document.getElementById("ios-plan-duration");
    const scenesContainer = document.getElementById("ios-scenes-preview");
    const audioTitle = document.getElementById("ios-audio-title");

    if (!planCard) return;

    if (durationLabel) {
        durationLabel.textContent = `${plan.totalSceneDuration}s • ${plan.scenes.length} Scenes`;
    }
    if (audioTitle && plan.audioPlan) {
        audioTitle.textContent = plan.audioPlan.trackTitle || "Cinematic Score";
    }

    if (scenesContainer) {
        scenesContainer.innerHTML = "";
        plan.scenes.forEach((sc, idx) => {
            const block = document.createElement("div");
            block.className = "scene-mini-block";
            block.innerHTML = `
                <div class="scene-mini-title">Scene ${idx + 1}</div>
                <div class="scene-mini-sub">${sc.duration}s • ${sc.transitionType || 'Cut'}</div>
            `;
            scenesContainer.appendChild(block);
        });
    }

    planCard.style.display = "flex";
}

// MARK: - Simulate Rendering Progression in Browser
function simulateRenderingFlow(plan) {
    const progressContainer = document.getElementById("progress-container");
    const progressBar = document.getElementById("progress-bar");
    const progressText = document.getElementById("progress-status-text");
    const trackerBadge = document.getElementById("tracker-stage-badge");

    if (progressContainer) progressContainer.style.display = "block";
    if (trackerBadge) {
        trackerBadge.className = "tracker-badge badge-active";
        trackerBadge.textContent = "RENDERING";
    }

    highlightFlow("flow-metal");
    setStepActive(4);
    setDynamicIsland("GPU Rendering", "pulse");

    let progress = 0;
    const interval = setInterval(() => {
        progress += 0.1;
        if (progressBar) progressBar.style.width = `${Math.min(progress * 100, 100)}%`;
        if (progressText) {
            const frame = Math.round(progress * 450);
            progressText.textContent = `Frame ${Math.min(frame, 450)} / 450 (${Math.round(progress * 100)}%) • 29.8 FPS`;
        }

        if (progress >= 1.0) {
            clearInterval(interval);
            highlightFlow("flow-video");
            highlightFlow("flow-grafana");
            setStepActive(5);
            setDynamicIsland("Ready", "ready");

            if (trackerBadge) {
                trackerBadge.className = "tracker-badge badge-done";
                trackerBadge.textContent = "COMPLETED";
            }

            // Show Video Card in Phone
            const videoCard = document.getElementById("ios-video-card");
            const player = document.getElementById("ios-preview-player");
            if (videoCard) videoCard.style.display = "flex";
            if (player) {
                player.src = "/static/sample_render.mp4";
                player.play().catch(() => {});
            }

            addAssistantMessage("✅ Simulation complete! 1080p H.264 stream validated. Ready for playback, photo library export, and project sharing.");
            fetchAuditLogs();
            fetchAnalytics();
        }
    }, 200);
}

// MARK: - Helper UI Updates
function addAssistantMessage(text) {
    const feed = document.getElementById("ios-chat-feed");
    if (!feed) return;

    const bubble = document.createElement("div");
    bubble.className = "chat-bubble assistant-bubble";
    bubble.innerHTML = `
        <div class="bubble-avatar">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>
        </div>
        <div class="bubble-content"><p>${text}</p></div>
    `;
    feed.appendChild(bubble);
    feed.scrollTop = feed.scrollHeight;
}

function setDynamicIsland(text, state) {
    const pill = document.getElementById("island-pill");
    const islandText = document.getElementById("island-text");
    if (islandText) islandText.textContent = text;
}

function highlightFlow(nodeId) {
    document.querySelectorAll(".flow-node").forEach(n => n.classList.remove("active"));
    const target = document.getElementById(nodeId);
    if (target) target.classList.add("active");
}

function setStepActive(stepNum) {
    for (let i = 1; i <= 5; i++) {
        const step = document.getElementById(`step-${i}`);
        if (!step) continue;
        if (i < stepNum) {
            step.className = "step-item completed";
        } else if (i === stepNum) {
            step.className = "step-item active";
        } else {
            step.className = "step-item";
        }
    }
}

// MARK: - Real-Time WebSocket
function initWebSocket() {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsURL = `${protocol}//${window.location.host}/ws/web`;

    try {
        webSocket = new WebSocket(wsURL);
        webSocket.onopen = () => {
            console.log("[WebSocket] Connected to Web Companion Hub");
        };

        webSocket.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                handleWebSocketMessage(msg);
            } catch (e) {}
        };
    } catch (e) {}
}

function handleWebSocketMessage(msg) {
    if (msg.type === "DEVICE_ONLINE") {
        isRealDeviceConnected = true;
        updateDeviceStatus(true, msg.deviceName || "iPhone 11");
    } else if (msg.type === "DEVICE_OFFLINE") {
        isRealDeviceConnected = false;
        updateDeviceStatus(false, null);
    } else if (msg.type === "PROGRESS_UPDATE") {
        updateLiveProgress(msg);
    } else if (msg.type === "GENERATION_COMPLETED") {
        completeRemoteGeneration(msg);
    }
}

function updateDeviceStatus(connected, name) {
    const dot = document.getElementById("device-dot");
    const label = document.getElementById("device-label");
    const sub = document.getElementById("real-iphone-status-sub");
    const metricDev = document.getElementById("metric-devices");

    if (connected) {
        if (dot) dot.className = "device-dot dot-connected";
        if (label) label.textContent = `${name || 'iPhone'} Connected`;
        if (sub) sub.textContent = `Online (${name || 'Apple Silicon'})`;
        if (metricDev) metricDev.textContent = `1 (${name})`;
    } else {
        if (dot) dot.className = "device-dot dot-waiting";
        if (label) label.textContent = "Waiting for iPhone...";
        if (sub) sub.textContent = "Waiting for device connection...";
        if (metricDev) metricDev.textContent = "0 (Simulator Active)";
    }
}

function updateLiveProgress(msg) {
    const progressBar = document.getElementById("progress-bar");
    const progressText = document.getElementById("progress-status-text");
    const container = document.getElementById("progress-container");

    if (container) container.style.display = "block";
    if (progressBar && msg.progress !== undefined) {
        progressBar.style.width = `${Math.min(msg.progress * 100, 100)}%`;
    }
    if (progressText && msg.progressMessage) {
        progressText.textContent = `${msg.progressMessage} (${Math.round((msg.progress || 0) * 100)}%)`;
    }
}

function completeRemoteGeneration(msg) {
    fetchAuditLogs();
    fetchAnalytics();
}

// MARK: - Backend Telemetry & Health
async function fetchBackendHealth() {
    try {
        const resp = await fetch("/api/v1/health");
        const data = await resp.json();
        const bText = document.getElementById("backend-status-text");
        if (bText) bText.textContent = data.environment === "production" ? "Render Production Live" : "FastAPI Live";

        if (data.devices) {
            updateDeviceStatus(data.devices.connectedCount > 0, "iPhone");
        }
    } catch (e) {}
}

async function fetchAnalytics() {
    try {
        const resp = await fetch("/api/v1/analytics");
        const data = await resp.json();
        const jobCount = document.getElementById("metric-jobs");
        const artCount = document.getElementById("metric-artifacts");
        if (jobCount) jobCount.textContent = data.totalGenerations || 0;
        if (artCount) artCount.textContent = data.totalArtifacts || 0;
    } catch (e) {}
}

async function fetchAuditLogs() {
    try {
        const resp = await fetch("/api/v1/audit");
        const data = await resp.json();
        const list = document.getElementById("audit-log-list");
        if (!list || !data.events) return;

        list.innerHTML = "";
        if (data.events.length === 0) {
            list.innerHTML = '<div class="audit-empty">No audit events recorded yet.</div>';
            return;
        }

        data.events.slice(0, 10).forEach(ev => {
            const row = document.createElement("div");
            row.className = "audit-row";
            const time = new Date(ev.timestamp).toLocaleTimeString();
            row.innerHTML = `
                <span class="audit-time">${time}</span>
                <span class="audit-action">${ev.action}</span>
                <span class="audit-desc">${ev.description || ''}</span>
            `;
            list.appendChild(row);
        });
    } catch (e) {}
}
