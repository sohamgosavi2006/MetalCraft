/**
 * MetalCraft Web Companion — Controller
 * Handles tab switching, API integration, WebSocket, prompt flow,
 * Dynamic Island state machine, and appearance toggle.
 */

(function () {
  'use strict';

  // ── Configuration ──────────────────────────────────────
  const API_BASE = window.location.origin;
  const WS_PROTOCOL = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const WS_URL = `${WS_PROTOCOL}//${window.location.host}/ws/web`;

  // ── State ──────────────────────────────────────────────
  let ws = null;
  let wsReconnectTimer = null;
  let isSubmitting = false;
  let currentEditPlan = null;
  let generationProgress = 0;
  let healthData = null;

  // ── DOM References ─────────────────────────────────────
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  // Tab system
  const tabItems = $$('.tab-item');
  const tabPanels = $$('.tab-panel');

  // Prompt
  const promptInput = $('#prompt-input');
  const promptSend = $('#prompt-send');
  const chatMessages = $('#chat-messages');
  const aiHero = $('#ai-hero');

  // Dynamic Island
  const dynamicIsland = $('#dynamic-island');
  const diContent = $('#di-content');
  const diIcon = $('#di-icon');
  const diText = $('#di-text');
  const diProgressWrap = $('#di-progress-wrap');
  const diProgressFill = $('#di-progress-fill');

  // Settings
  const settingsBtn = $('#ai-settings-btn');
  const settingsOverlay = $('#settings-overlay');
  const settingsSheet = $('#settings-sheet');

  // Analytics sub-sections
  const analyticsPills = $$('#analytics-pills .section-pill');

  // ── Init ───────────────────────────────────────────────
  function init() {
    updateSimulatorTime();
    setInterval(updateSimulatorTime, 30000);

    initTabSwitching();
    initAppearance();
    initPromptFlow();
    initSettings();
    initAnalyticsPills();
    initProjectFilters();
    initEditorActions();
    initNavLinks();

    fetchHealth();
    setInterval(fetchHealth, 30000);
    fetchAudit();
    setInterval(fetchAudit, 60000);

    connectWebSocket();
  }

  // ── Simulator Time ─────────────────────────────────────
  function updateSimulatorTime() {
    const now = new Date();
    let h = now.getHours();
    const m = now.getMinutes().toString().padStart(2, '0');
    const timeStr = `${h}:${m}`;
    const el = $('#sim-time');
    if (el) el.textContent = timeStr;
  }

  // ── Tab Switching ──────────────────────────────────────
  function initTabSwitching() {
    tabItems.forEach(item => {
      item.addEventListener('click', () => {
        const tabId = item.dataset.tab;
        switchTab(tabId);
      });
    });
  }

  function switchTab(tabId) {
    // Deactivate all
    tabItems.forEach(t => t.classList.remove('active'));
    tabPanels.forEach(p => p.classList.remove('active'));

    // Activate clicked
    const panel = $(`#panel-${tabId}`);
    const tabBtn = $(`.tab-item[data-tab="${tabId}"]`);
    if (panel) panel.classList.add('active');
    if (tabBtn) tabBtn.classList.add('active');
  }

  // ── Appearance Toggle ──────────────────────────────────
  function initAppearance() {
    const stored = localStorage.getItem('mc-theme');
    if (stored === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
    } else if (stored === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
    }

    updateAppearanceButtons();

    $$('.appearance-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const val = btn.dataset.themeVal;
        if (val === 'system') {
          document.documentElement.removeAttribute('data-theme');
          localStorage.removeItem('mc-theme');
        } else {
          document.documentElement.setAttribute('data-theme', val);
          localStorage.setItem('mc-theme', val);
        }
        updateAppearanceButtons();
      });
    });
  }

  function updateAppearanceButtons() {
    const current = document.documentElement.getAttribute('data-theme');
    $$('.appearance-btn').forEach(btn => {
      const val = btn.dataset.themeVal;
      if (current === val || (!current && val === 'system')) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  }

  // ── Settings Sheet ─────────────────────────────────────
  function initSettings() {
    if (settingsBtn) {
      settingsBtn.addEventListener('click', () => {
        settingsOverlay.classList.add('active');
        settingsSheet.classList.add('active');
      });
    }
    if (settingsOverlay) {
      settingsOverlay.addEventListener('click', () => {
        settingsOverlay.classList.remove('active');
        settingsSheet.classList.remove('active');
      });
    }

    // Set endpoint display
    const endpointEl = $('#settings-endpoint');
    if (endpointEl) {
      endpointEl.textContent = window.location.hostname === 'localhost' ? 'localhost:8080' : 'Render Cloud';
    }
  }

  // ── Nav Links (scroll to section) ──────────────────────
  function initNavLinks() {
    $$('.nav-link').forEach(link => {
      link.addEventListener('click', (e) => {
        $$('.nav-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
      });
    });
  }

  // ── Editor Actions ─────────────────────────────────────
  function initEditorActions() {
    const openProjects = $('#editor-open-projects');
    if (openProjects) {
      openProjects.addEventListener('click', () => switchTab('projects'));
    }
  }

  // ── Analytics Section Pills ────────────────────────────
  function initAnalyticsPills() {
    analyticsPills.forEach(pill => {
      pill.addEventListener('click', () => {
        analyticsPills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');

        const section = pill.dataset.section;
        const overviewEl = $('#analytics-overview');
        const pipelineEl = $('#analytics-pipeline');

        if (section === 'overview') {
          overviewEl.style.display = '';
          pipelineEl.style.display = 'none';
        } else {
          overviewEl.style.display = 'none';
          pipelineEl.style.display = '';
        }
      });
    });
  }

  // ── Project Filters ────────────────────────────────────
  function initProjectFilters() {
    $$('.filter-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        $$('.filter-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
      });
    });
  }

  // ── Prompt Flow ────────────────────────────────────────
  function initPromptFlow() {
    // Send button
    if (promptSend) {
      promptSend.addEventListener('click', submitPrompt);
    }

    // Enter key
    if (promptInput) {
      promptInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          submitPrompt();
        }
      });
    }

    // Suggestion pills
    $$('.suggestion-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        const prompt = pill.dataset.prompt;
        if (promptInput) promptInput.value = prompt;
        submitPrompt();
      });
    });
  }

  async function submitPrompt() {
    if (isSubmitting) return;
    const text = promptInput ? promptInput.value.trim() : '';
    if (!text) return;

    isSubmitting = true;
    promptInput.value = '';
    updateSendButton(true);

    // Hide hero, show chat
    if (aiHero) aiHero.style.display = 'none';

    // Add user message
    appendMessage('user', text);

    // Expand Dynamic Island — thinking
    setDynamicIsland('thinking', 'Gemini Thinking…');

    // Highlight pipeline flow
    highlightFlowNode('flow-user');

    try {
      const res = await fetch(`${API_BASE}/api/v1/agent/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: text,
          mediaMetadata: {
            type: 'video',
            assets: [
              { id: 'img_1', type: 'image', name: 'Image 1' },
              { id: 'img_2', type: 'image', name: 'Image 2' },
              { id: 'img_3', type: 'image', name: 'Image 3' },
              { id: 'img_4', type: 'image', name: 'Image 4' },
              { id: 'img_5', type: 'image', name: 'Image 5' },
              { id: 'img_6', type: 'image', name: 'Image 6' },
              { id: 'img_7', type: 'image', name: 'Image 7' },
              { id: 'img_8', type: 'image', name: 'Image 8' },
              { id: 'vid_1', type: 'video', name: 'Video 1' }
            ],
            aspectRatio: '9:16'
          }
        })
      });

      const data = await res.json();
      highlightFlowNode('flow-gemini');

      // Agent response message
      appendMessage('agent', data.reasoning || 'Creative plan formulated.');

      // Show EditPlan card
      if (data.editPlan) {
        currentEditPlan = data.editPlan;
        renderEditPlanCard(data);
        highlightFlowNode('flow-editplan');
      }

      setDynamicIsland('idle');
      updateGenStatus('Plan Ready', data.editPlan?.goal || text);

    } catch (err) {
      appendMessage('agent', `Error: ${err.message}. Please check that the backend is running.`);
      setDynamicIsland('idle');
    }

    isSubmitting = false;
    updateSendButton(false);
  }

  function updateSendButton(loading) {
    if (!promptSend) return;
    if (loading) {
      promptSend.disabled = true;
      promptSend.innerHTML = '<div class="spinner"></div>';
    } else {
      promptSend.disabled = false;
      promptSend.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l0 20M12 2l-7 7M12 2l7 7"/></svg>';
    }
  }

  // ── Chat Messages ──────────────────────────────────────
  function appendMessage(type, text) {
    const el = document.createElement('div');
    el.className = `msg-bubble msg-${type}`;
    if (type === 'agent') {
      el.innerHTML = `<div class="msg-label">Gemini Creative Director</div><p>${text}</p>`;
    } else {
      el.textContent = text;
    }
    chatMessages.appendChild(el);
    el.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }

  // ── EditPlan Card ──────────────────────────────────────
  function renderEditPlanCard(data) {
    const plan = data.editPlan;
    const card = document.createElement('div');
    card.className = 'edit-plan-card';

    const scenes = plan.scenes || [];
    const totalDuration = scenes.reduce((s, sc) => s + (sc.duration || 0), 0);

    card.innerHTML = `
      <div class="plan-header">
        <span class="plan-title">EditPlan — ${plan.planId || 'draft'}</span>
        <span class="plan-confidence">${((data.confidence || 0.92) * 100).toFixed(0)}%</span>
      </div>
      <div class="plan-body">
        <div class="plan-detail"><span>Goal</span><strong>${plan.goal || '—'}</strong></div>
        <div class="plan-detail"><span>Scenes</span><strong>${scenes.length}</strong></div>
        <div class="plan-detail"><span>Duration</span><strong>${totalDuration.toFixed(1)}s</strong></div>
        <div class="plan-detail"><span>Aspect</span><strong>${plan.aspectRatio || '9:16'}</strong></div>
        <div class="plan-detail"><span>Audio</span><strong>${plan.audioPlan?.trackTitle || 'Auto'}</strong></div>
      </div>
      <div class="plan-actions">
        <button class="plan-btn reject" id="plan-reject-btn">Modify</button>
        <button class="plan-btn approve" id="plan-approve-btn">Approve & Render</button>
      </div>
    `;

    chatMessages.appendChild(card);
    card.scrollIntoView({ behavior: 'smooth', block: 'end' });

    // Approve button
    card.querySelector('#plan-approve-btn').addEventListener('click', () => startGeneration(plan));
    card.querySelector('#plan-reject-btn').addEventListener('click', () => {
      appendMessage('agent', 'Plan modification requested. Please provide updated instructions.');
    });
  }

  // ── Start Generation ───────────────────────────────────
  async function startGeneration(plan) {
    setDynamicIsland('rendering', 'Rendering…', 0);
    highlightFlowNode('flow-metal');
    updateGenStatus('Rendering', 'Dispatching to Metal GPU…');

    try {
      const res = await fetch(`${API_BASE}/api/v1/generations`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plan: plan,
          projectName: 'MetalCraft Soham'
        })
      });

      const data = await res.json();

      if (data.dispatchedToDevice) {
        appendMessage('agent', `Generation ${data.generationId} dispatched to connected iPhone. Metal GPU rendering in progress.`);
        updateGenStatus('On Device', data.generationId);
      } else {
        // Simulate rendering progress in browser
        appendMessage('agent', `No iPhone connected. Simulating render progress for ${data.generationId}.`);
        simulateRenderProgress(data.generationId);
      }
    } catch (err) {
      appendMessage('agent', `Generation dispatch error: ${err.message}`);
      setDynamicIsland('idle');
    }
  }

  function simulateRenderProgress(genId) {
    generationProgress = 0;

    // Add progress card
    const card = document.createElement('div');
    card.className = 'gen-progress-card';
    card.id = `gen-card-${genId}`;
    card.innerHTML = `
      <div class="gen-progress-header">
        <span class="gen-progress-title">Rendering — Simulator</span>
        <span class="gen-progress-pct" id="gen-pct-${genId}">0%</span>
      </div>
      <div class="gen-progress-bar">
        <div class="gen-progress-fill" id="gen-fill-${genId}" style="width:0%"></div>
      </div>
      <div class="gen-progress-msg" id="gen-msg-${genId}">Initializing Metal shaders…</div>
    `;
    chatMessages.appendChild(card);
    card.scrollIntoView({ behavior: 'smooth', block: 'end' });

    const messages = [
      'Initializing Metal shaders…',
      'Processing Scene 1/4 — zoomIn…',
      'Processing Scene 2/4 — crossfade…',
      'Processing Scene 3/4 — panLeft…',
      'Processing Scene 4/4 — zoomOut…',
      'Compositing audio track…',
      'AVFoundation export…',
      'Finalizing MP4 container…'
    ];

    const interval = setInterval(() => {
      generationProgress += Math.random() * 8 + 4;
      if (generationProgress >= 100) generationProgress = 100;

      const pctEl = $(`#gen-pct-${genId}`);
      const fillEl = $(`#gen-fill-${genId}`);
      const msgEl = $(`#gen-msg-${genId}`);

      if (pctEl) pctEl.textContent = `${Math.round(generationProgress)}%`;
      if (fillEl) fillEl.style.width = `${generationProgress}%`;

      const msgIdx = Math.min(Math.floor((generationProgress / 100) * messages.length), messages.length - 1);
      if (msgEl) msgEl.textContent = messages[msgIdx];

      setDynamicIsland('rendering', `${Math.round(generationProgress)}%`, generationProgress);

      if (generationProgress >= 100) {
        clearInterval(interval);
        setTimeout(() => completeGeneration(genId), 600);
      }
    }, 800);
  }

  function completeGeneration(genId) {
    setDynamicIsland('done', 'Complete ✓');
    highlightFlowNode('flow-video');
    updateGenStatus('Complete', genId);

    // Add video preview card
    const card = document.createElement('div');
    card.className = 'video-preview-card';
    card.innerHTML = `
      <div class="video-preview-thumb">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polygon points="5 3 19 12 5 21 5 3"/></svg>
      </div>
      <div class="video-preview-info">
        <h4>Video Generated — ${genId}</h4>
        <p>9:16 · MP4 · Simulated render complete. Connect an iPhone for real Metal GPU output.</p>
      </div>
    `;
    chatMessages.appendChild(card);
    card.scrollIntoView({ behavior: 'smooth', block: 'end' });

    // Reset Dynamic Island after 3 seconds
    setTimeout(() => setDynamicIsland('idle'), 3000);
  }

  // ── Dynamic Island State Machine ───────────────────────
  function setDynamicIsland(state, text, progress) {
    if (state === 'idle') {
      dynamicIsland.classList.remove('expanded');
      return;
    }

    dynamicIsland.classList.add('expanded');

    if (state === 'thinking') {
      diIcon.className = 'di-icon thinking';
      diIcon.textContent = '✦';
      diText.textContent = text || 'Thinking…';
      diProgressWrap.style.display = 'none';
    } else if (state === 'rendering') {
      diIcon.className = 'di-icon rendering';
      diIcon.textContent = '◉';
      diText.textContent = text || 'Rendering…';
      diProgressWrap.style.display = '';
      diProgressFill.style.width = `${progress || 0}%`;
    } else if (state === 'done') {
      diIcon.className = 'di-icon done';
      diIcon.textContent = '✓';
      diText.textContent = text || 'Done';
      diProgressWrap.style.display = 'none';
    }
  }

  // ── Pipeline Flow Highlighting ─────────────────────────
  function highlightFlowNode(nodeId) {
    $$('.flow-node-icon').forEach(n => n.classList.remove('active'));
    const node = $(`#${nodeId}`);
    if (node) node.classList.add('active');
  }

  // ── Generation Status (side panel) ─────────────────────
  function updateGenStatus(status, detail) {
    const statusEl = $('#gen-status-display');
    const detailEl = $('#gen-detail-text');
    if (statusEl) statusEl.textContent = status;
    if (detailEl) detailEl.textContent = detail || '';
  }

  // ── Health Check ───────────────────────────────────────
  async function fetchHealth() {
    try {
      const res = await fetch(`${API_BASE}/api/v1/health`);
      const data = await res.json();
      healthData = data;

      // Update header status
      const backendText = $('#backend-status-text');
      if (backendText) backendText.textContent = data.status === 'healthy' ? 'Cloud Live' : 'Degraded';

      // Device status
      const deviceDot = $('#device-dot');
      const deviceText = $('#device-status-text');
      const deviceDisplay = $('#device-state-display');

      if (data.devices?.connectedCount > 0) {
        if (deviceDot) { deviceDot.className = 'status-dot dot-online'; }
        if (deviceText) deviceText.textContent = `${data.devices.connectedCount} iPhone`;
        if (deviceDisplay) deviceDisplay.textContent = 'Connected';
      } else {
        if (deviceDot) { deviceDot.className = 'status-dot dot-waiting'; }
        if (deviceText) deviceText.textContent = 'No Device';
        if (deviceDisplay) deviceDisplay.textContent = 'Waiting…';
      }

      // Provider statuses (side panel)
      updateProviderStatus('health-gemini', data.providers?.gemini);
      updateProviderStatus('health-parallel', data.providers?.parallel);
      updateProviderStatus('health-grafana', data.providers?.grafana);

      // Provider statuses (cloud section)
      updateProviderCard('provider-gemini-status', data.providers?.gemini);
      updateProviderCard('provider-parallel-status', data.providers?.parallel);
      updateProviderCard('provider-grafana-status', data.providers?.grafana);

    } catch (err) {
      const backendText = $('#backend-status-text');
      if (backendText) backendText.textContent = 'Offline';
    }
  }

  function updateProviderStatus(elId, provider) {
    const el = $(`#${elId}`);
    if (!el || !provider) return;
    const status = provider.status || 'UNKNOWN';
    el.textContent = status;
    el.className = 'side-card-value';
    if (status === 'PASS') el.classList.add('pass');
    else if (status === 'WARN') el.classList.add('warn');
    else el.classList.add('fail');
  }

  function updateProviderCard(elId, provider) {
    const el = $(`#${elId}`);
    if (!el || !provider) return;
    const status = provider.status || 'UNKNOWN';
    const latency = provider.latencyMs ? `${provider.latencyMs.toFixed(0)}ms` : '';
    el.className = 'provider-status';
    if (status === 'PASS') {
      el.classList.add('pass');
      el.innerHTML = `<span class="dot"></span><span>Connected${latency ? ` · ${latency}` : ''}</span>`;
    } else if (status === 'WARN') {
      el.classList.add('warn');
      el.innerHTML = `<span class="dot"></span><span>Warning${latency ? ` · ${latency}` : ''}</span>`;
    } else {
      el.classList.add('fail');
      el.innerHTML = `<span class="dot"></span><span>Unavailable</span>`;
    }
  }

  // ── Audit Trail ────────────────────────────────────────
  async function fetchAudit() {
    try {
      const res = await fetch(`${API_BASE}/api/v1/audit`);
      const data = await res.json();
      const events = data.events || data.auditEvents || [];

      // Populate table
      const tbody = $('#audit-tbody');
      if (tbody && events.length > 0) {
        tbody.innerHTML = events.slice(0, 20).map(ev => {
          const time = ev.createdAt ? new Date(ev.createdAt).toLocaleTimeString() : '—';
          const statusClass = ev.status === 'SUCCESS' ? 'success' : 'info';
          return `<tr>
            <td>${time}</td>
            <td>${ev.category || '—'}</td>
            <td>${ev.action || '—'}</td>
            <td><span class="audit-status ${statusClass}">${ev.status || '—'}</span></td>
            <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${ev.description || '—'}</td>
          </tr>`;
        }).join('');
      } else if (tbody && events.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:var(--text-tertiary);padding:24px;">No audit events recorded yet.</td></tr>';
      }

      // Mini audit (side panel)
      const miniList = $('#audit-mini-list');
      if (miniList && events.length > 0) {
        miniList.innerHTML = events.slice(0, 5).map(ev =>
          `<div style="padding:4px 0;border-bottom:0.5px solid var(--separator);">
            <div style="font-weight:600;font-size:12px;">${ev.action || '—'}</div>
            <div style="font-size:11px;color:var(--text-tertiary);">${ev.category || ''} · ${ev.status || ''}</div>
          </div>`
        ).join('');
      } else if (miniList) {
        miniList.innerHTML = '<p>No events yet.</p>';
      }

    } catch (err) {
      // Audit endpoint may not exist yet
    }
  }

  // ── WebSocket ──────────────────────────────────────────
  function connectWebSocket() {
    const wsDot = $('#ws-dot');
    const wsLabel = $('#ws-label');

    try {
      ws = new WebSocket(WS_URL);

      ws.onopen = () => {
        if (wsDot) { wsDot.className = 'ws-dot connected'; }
        if (wsLabel) wsLabel.textContent = 'WebSocket Connected';
        if (wsReconnectTimer) { clearTimeout(wsReconnectTimer); wsReconnectTimer = null; }
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          handleWSMessage(msg);
        } catch (e) { /* ignore non-JSON */ }
      };

      ws.onclose = () => {
        if (wsDot) { wsDot.className = 'ws-dot disconnected'; }
        if (wsLabel) wsLabel.textContent = 'Disconnected';
        scheduleReconnect();
      };

      ws.onerror = () => {
        if (wsDot) { wsDot.className = 'ws-dot disconnected'; }
        if (wsLabel) wsLabel.textContent = 'Connection Error';
      };
    } catch (err) {
      if (wsDot) { wsDot.className = 'ws-dot disconnected'; }
      if (wsLabel) wsLabel.textContent = 'Unavailable';
      scheduleReconnect();
    }
  }

  function scheduleReconnect() {
    if (wsReconnectTimer) return;
    wsReconnectTimer = setTimeout(() => {
      wsReconnectTimer = null;
      connectWebSocket();
    }, 5000);
  }

  function handleWSMessage(msg) {
    switch (msg.type) {
      case 'DEVICE_STATUS_CHANGED':
        fetchHealth();
        break;

      case 'GENERATION_DISPATCHED':
        appendMessage('agent', `Generation ${msg.generationId} dispatched. Status: ${msg.status}`);
        break;

      case 'GENERATION_PROGRESS':
        // Update progress card if visible
        const pctEl = $(`#gen-pct-${msg.generationId}`);
        const fillEl = $(`#gen-fill-${msg.generationId}`);
        const msgEl = $(`#gen-msg-${msg.generationId}`);
        if (pctEl) pctEl.textContent = `${Math.round(msg.progress || 0)}%`;
        if (fillEl) fillEl.style.width = `${msg.progress || 0}%`;
        if (msgEl) msgEl.textContent = msg.progressMessage || '';
        setDynamicIsland('rendering', `${Math.round(msg.progress || 0)}%`, msg.progress || 0);
        break;

      case 'GENERATION_COMPLETE':
        completeGeneration(msg.generationId);
        break;
    }
  }

  // ── Boot ───────────────────────────────────────────────
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
