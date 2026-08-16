/**
 * MetalCraft — Premium Apple/iOS Web Simulator & Control Plane Controller
 * Interacts with FastAPI Cloud Backend, WebSockets, and mirrors the iOS App.
 */

let activePlan = null;
let currentGenerationId = null;
let webSocket = null;
let isRealDeviceConnected = false;

document.addEventListener("DOMContentLoaded", () => {
    initSimulatorTabBar();
    initSettingsModal();
    initPromptComposer();
    initStyleChips();
    initProjectSelection();
    initEditorSubTabs();
    initWebSocketHub();
    
    // Initial fetch
    fetchBackendHealth();
    fetchAnalytics();
    fetchAuditLogs();

    // Periodic background sync
    setInterval(() => {
        fetchBackendHealth();
        fetchAnalytics();
        fetchAuditLogs();
    }, 7000);
});

// MARK: - Native iOS Bottom TabBar Navigation
function initSimulatorTabBar() {
    const tabButtons = document.querySelectorAll(".tab-item");
    const views = document.querySelectorAll(".ios-tab-view");
    const titleLabel = document.getElementById("ios-screen-title");

    const titles = {
        "editor": "Editor",
        "ai-create": "AI Create Studio",
        "analytics": "Observability",
        "projects": "Projects"
    };

    tabButtons.forEach(btn => {
        btn.addEventListener("click", () => {
            const target = btn.getAttribute("data-tab");
            tabButtons.forEach(b => b.classList.remove("active"));
            views.forEach(v => v.classList.remove("active"));

            btn.classList.add("active");
            const activeView = document.getElementById(`view-${target}`);
            if (activeView) activeView.classList.add("active");

            if (titleLabel && titles[target]) {
                titleLabel.textContent = titles[target];
            }
        });
    });
}

// MARK: - iOS Settings Sheet (Slide-Over)
function initSettingsModal() {
    const sheet = document.getElementById("ios-settings-sheet");
    const btnOpen = document.getElementById("btn-open-settings");
    const btnClose = document.getElementById("btn-close-settings");

    if (btnOpen && sheet) {
        btnOpen.addEventListener("click", () => sheet.classList.add("open"));
    }
    if (btnClose && sheet) {
        btnClose.addEventListener("click", () => sheet.classList.remove("open"));
    }
}

// MARK: - Quick Style Chips
function initStyleChips() {
    document.querySelectorAll(".ios-style-chip").forEach(chip => {
        chip.addEventListener("click", () => {
            const prompt = chip.getAttribute("data-prompt");
            const input = document.getElementById("sim-prompt-input");
            if (input) {
                input.value = prompt;
                input.focus();
            }
        });
    });
}

// MARK: - Projects Browser in Phone
function initProjectSelection() {
    document.querySelectorAll(".ios-project-row").forEach(row => {
        row.addEventListener("click", () => {
            document.querySelectorAll(".ios-project-row").forEach(r => r.classList.remove("active"));
            row.classList.add("active");
            const name = row.getAttribute("data-proj");
            const headerProj = document.getElementById("active-project-name");
            if (headerProj && name) headerProj.textContent = name;
        });
    });
}

// MARK: - Editor Sub Tabs
function initEditorSubTabs() {
    const subTabs = document.querySelectorAll(".sub-tab");
    subTabs.forEach(st => {
        st.addEventListener("click", () => {
            subTabs.forEach(t => t.classList.remove("active"));
            st.classList.add("active");
        });
    });
}

// MARK: - AI Prompt Composition & Synthesis
function initPromptComposer() {
    const btnSend = document.getElementById("btn-sim-send");
    const btnHeroSynth = document.getElementById("btn-hero-synthesize");
    const btnHeroDispatch = document.getElementById("btn-hero-dispatch");
    const promptInput = document.getElementById("sim-prompt-input");

    async function triggerDirectorSynthesis() {
        const prompt = promptInput.value.trim();
        if (!prompt) return;

        setDynamicIsland("Directing...", "✨");
        highlightPipelineNode("node-gemini");
        appendAssistantMessage(`Analyzing cinematography parameters for: "${prompt}"...`);

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
                            { id: "media_001", name: "Product Hero Shot", type: "image", width: 1080, height: 1920 },
                            { id: "media_002", name: "Macro Detail Shot", type: "image", width: 1080, height: 1920 },
                            { id: "media_003", name: "Lifestyle In-Use", type: "image", width: 1080, height: 1920 }
                        ]
                    }
                })
            });

            const data = await resp.json();
            if (data.editPlan) {
                activePlan = data.editPlan;
                highlightPipelineNode("node-parallel");

                setTimeout(() => {
                    highlightPipelineNode("node-plan");
                    renderEditPlanCard(activePlan);
                    appendAssistantMessage(`✓ Formulated ${activePlan.scenes.length}-scene timeline (${activePlan.totalSceneDuration}s) with soundtrack '${activePlan.audioPlan?.trackTitle || 'Cinematic Flow'}'. Synthesized for Apple Metal GPU.`);
                    setDynamicIsland("Plan Ready", "📋");

                    if (btnHeroDispatch) btnHeroDispatch.disabled = false;

                    // Automatically simulate Metal execution
                    startMetalRenderingSimulation(activePlan);
                }, 500);
            }
        } catch (err) {
            appendAssistantMessage(`Error synthesizing plan: ${err.message}`);
            setDynamicIsland("Error", "⚠️");
        }
    }

    if (btnSend) btnSend.addEventListener("click", triggerDirectorSynthesis);
    if (btnHeroSynth) btnHeroSynth.addEventListener("click", triggerDirectorSynthesis);

    if (promptInput) {
        promptInput.addEventListener("keydown", (e) => {
            if (e.key === "Enter") triggerDirectorSynthesis();
        });
    }

    // Dispatch Command to Physical iPhone
    if (btnHeroDispatch) {
        btnHeroDispatch.addEventListener("click", async () => {
            if (!activePlan) return;
            appendAssistantMessage("📡 Dispatching EditPlan command to connected Apple device over WebSocket...");
            setDynamicIsland("Dispatching...", "📲");

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
                appendAssistantMessage(`🚀 Job ${job.generationId} queued. Streaming Apple Metal GPU frames...`);
            } catch (err) {
                appendAssistantMessage(`Failed to dispatch job: ${err.message}`);
            }
        });
    }

    // Video Card Actions
    const btnPhotos = document.getElementById("btn-sim-photos");
    const btnAddProj = document.getElementById("btn-sim-add-project");
    const btnShare = document.getElementById("btn-sim-share");

    if (btnPhotos) {
        btnPhotos.addEventListener("click", () => {
            alert("✅ Saved to Photos: 1080p H.264 video exported directly to your iOS Photos Library.");
        });
    }
    if (btnAddProj) {
        btnAddProj.addEventListener("click", () => {
            alert("✅ Added to Project: Video artifact registered under active project videos.");
        });
    }
    if (btnShare) {
        btnShare.addEventListener("click", () => {
            if (navigator.share) {
                navigator.share({ title: "MetalCraft Reel", text: "Created with MetalCraft on Apple Metal GPU." }).catch(() => {});
            } else {
                alert("📤 iOS Share Sheet: Ready to export reel.");
            }
        });
    }
}

// MARK: - Render EditPlan Card inside Phone
function renderEditPlanCard(plan) {
    const card = document.getElementById("ui-plan-card");
    const goalText = document.getElementById("plan-goal-text");
    const durMeta = document.getElementById("plan-meta-duration");
    const aspectMeta = document.getElementById("plan-meta-aspect");
    const scenesMeta = document.getElementById("plan-meta-scenes");
    const timeline = document.getElementById("plan-scenes-timeline");
    const soundText = document.getElementById("plan-soundtrack-name");

    if (!card) return;

    if (goalText) goalText.textContent = plan.goal || "Cinematic Reel";
    if (durMeta) durMeta.textContent = `${plan.totalSceneDuration}s`;
    if (aspectMeta) aspectMeta.textContent = plan.aspectRatio || "9:16";
    if (scenesMeta) scenesMeta.textContent = `${plan.scenes.length} Scenes`;
    if (soundText && plan.audioPlan) soundText.textContent = `${plan.audioPlan.trackTitle || 'Soundtrack'} (${plan.totalSceneDuration}s)`;

    if (timeline) {
        timeline.innerHTML = "";
        plan.scenes.forEach((sc, idx) => {
            const chip = document.createElement("div");
            chip.className = "timeline-scene-chip";
            chip.innerHTML = `
                <div class="scene-chip-num">Scene ${idx + 1}</div>
                <div class="scene-chip-time">${sc.duration}s &bull; ${sc.transitionType || 'Cut'}</div>
            `;
            timeline.appendChild(chip);
        });
    }

    card.style.display = "flex";
}

// MARK: - Start Metal Rendering Simulation
function startMetalRenderingSimulation(plan) {
    const progCard = document.getElementById("ui-progress-card");
    const bar = document.getElementById("ios-progress-bar");
    const pct = document.getElementById("progress-pct-label");
    const sub = document.getElementById("progress-sub-label");
    const videoCard = document.getElementById("ui-video-card");
    const player = document.getElementById("sim-video-player");

    if (progCard) progCard.style.display = "flex";
    highlightPipelineNode("node-metal");
    setDynamicIsland("GPU Render", "⚡");

    let progress = 0;
    const interval = setInterval(() => {
        progress += 0.1;
        const pctVal = Math.min(Math.round(progress * 100), 100);
        const frameVal = Math.min(Math.round(progress * 450), 450);

        if (bar) bar.style.width = `${pctVal}%`;
        if (pct) pct.textContent = `${pctVal}%`;
        if (sub) sub.textContent = `Frame ${frameVal} / 450 • 29.8 FPS`;

        if (progress >= 1.0) {
            clearInterval(interval);
            highlightPipelineNode("node-video");
            highlightPipelineNode("node-grafana");
            setDynamicIsland("Production Ready", "✅");

            setTimeout(() => {
                if (progCard) progCard.style.display = "none";
                if (videoCard) videoCard.style.display = "flex";
                if (player) {
                    player.src = "/static/sample_render.mp4";
                    player.play().catch(() => {});
                }
                appendAssistantMessage("✅ Video production complete! 1080p H.264 stream validated. Ready for playback, photo library export, and project sharing.");
                fetchAuditLogs();
                fetchAnalytics();
            }, 400);
        }
    }, 200);
}

// MARK: - Assistant Message Stream Helper
function appendAssistantMessage(text) {
    const container = document.getElementById("dynamic-chat-messages");
    if (!container) return;

    const row = document.createElement("div");
    row.className = "chat-message-row assistant";
    row.innerHTML = `
        <div class="agent-avatar">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>
        </div>
        <div class="bubble-body"><p class="bubble-text">${text}</p></div>
    `;
    container.appendChild(row);

    const scrollBox = document.getElementById("chat-scroll-container");
    if (scrollBox) scrollBox.scrollTop = scrollBox.scrollHeight;
}

function setDynamicIsland(label, icon) {
    const labelEl = document.getElementById("island-label");
    const iconEl = document.getElementById("island-icon");
    if (labelEl) labelEl.textContent = label;
    if (iconEl) iconEl.textContent = icon;
}

function highlightPipelineNode(nodeId) {
    document.querySelectorAll(".flow-step-node").forEach(n => n.classList.remove("active"));
    const el = document.getElementById(nodeId);
    if (el) el.classList.add("active");
}

// MARK: - Real-Time WebSocket
function initWebSocketHub() {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsURL = `${protocol}//${window.location.host}/ws/web`;

    try {
        webSocket = new WebSocket(wsURL);
        webSocket.onopen = () => console.log("[WebSocket] Connected to Cloud Hub");
        webSocket.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                handleWebSocketEvent(msg);
            } catch (e) {}
        };
    } catch (e) {}
}

function handleWebSocketEvent(msg) {
    if (msg.type === "DEVICE_ONLINE") {
        updateDeviceConnectionUI(true, msg.deviceName || "iPhone 11");
    } else if (msg.type === "DEVICE_OFFLINE") {
        updateDeviceConnectionUI(false, null);
    } else if (msg.type === "PROGRESS_UPDATE") {
        updateHardwareProgress(msg);
    } else if (msg.type === "GENERATION_COMPLETED") {
        fetchAuditLogs();
        fetchAnalytics();
    }
}

function updateDeviceConnectionUI(connected, name) {
    const dot = document.getElementById("device-dot");
    const label = document.getElementById("device-status-text");
    const heroDot = document.getElementById("real-iphone-dot");
    const heroLabel = document.getElementById("real-iphone-label");
    const metricDev = document.getElementById("metric-devices");

    if (connected) {
        if (dot) dot.className = "status-dot dot-online";
        if (label) label.textContent = `${name || 'iPhone'} Connected`;
        if (heroDot) heroDot.className = "m-dot dot-online";
        if (heroLabel) heroLabel.textContent = `Online: ${name || 'iPhone'} (Apple Silicon)`;
        if (metricDev) metricDev.textContent = `1 (${name})`;
    } else {
        if (dot) dot.className = "status-dot dot-waiting";
        if (label) label.textContent = "Waiting for iPhone...";
        if (heroDot) heroDot.className = "m-dot dot-waiting";
        if (heroLabel) heroLabel.textContent = "Waiting for iPhone...";
        if (metricDev) metricDev.textContent = "0 (Simulator Active)";
    }
}

function updateHardwareProgress(msg) {
    const progCard = document.getElementById("ui-progress-card");
    const bar = document.getElementById("ios-progress-bar");
    const pct = document.getElementById("progress-pct-label");
    const sub = document.getElementById("progress-sub-label");

    if (progCard) progCard.style.display = "flex";
    if (bar && msg.progress !== undefined) bar.style.width = `${Math.min(msg.progress * 100, 100)}%`;
    if (pct && msg.progress !== undefined) pct.textContent = `${Math.round(msg.progress * 100)}%`;
    if (sub && msg.progressMessage) sub.textContent = msg.progressMessage;
}

// MARK: - Backend Telemetry & Audit Sync
async function fetchBackendHealth() {
    try {
        const resp = await fetch("/api/v1/health");
        const data = await resp.json();
        const bText = document.getElementById("backend-status-text");
        if (bText) bText.textContent = data.environment === "production" ? "Render Live" : "FastAPI Live";
        if (data.devices) updateDeviceConnectionUI(data.devices.connectedCount > 0, "iPhone");
    } catch (e) {}
}

async function fetchAnalytics() {
    try {
        const resp = await fetch("/api/v1/analytics");
        const data = await resp.json();
        const jCount = document.getElementById("metric-jobs");
        const aCount = document.getElementById("metric-artifacts");
        if (jCount) jCount.textContent = data.totalGenerations || 0;
        if (aCount) aCount.textContent = data.totalArtifacts || 0;
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
            list.innerHTML = '<div class="empty-state">No audit events recorded yet.</div>';
            return;
        }

        data.events.slice(0, 10).forEach(ev => {
            const row = document.createElement("div");
            row.className = "audit-row-item";
            const time = new Date(ev.timestamp).toLocaleTimeString();
            row.innerHTML = `
                <span class="ar-time">${time}</span>
                <span class="ar-action">${ev.action}</span>
                <span class="ar-desc">${ev.description || ''}</span>
            `;
            list.appendChild(row);
        });
    } catch (e) {}
}
