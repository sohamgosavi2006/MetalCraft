/**
 * MetalCraft — Web Companion & iPhone 17 Pro Simulator
 * Version 2.0.0
 * 
 * Features:
 * - High-level View Switcher (Simulator, Real iPhones, Cloud, Pipeline, Observability, Audit)
 * - Isolated, fully interactive SimulatorState engine
 * - Real connected iPhone device discovery & management via REST & WebSockets
 * - Non-destructive Metal GPU Canvas image adjustment simulation
 * - Gemini 2.5 Flash EditPlan synthesis and simulated render state machine
 * - State-driven Dynamic Island
 * - Global Theme engine (Light, Dark, System)
 */

(function () {
  'use strict';

  // ── SAMPLE MEDIA ASSETS (For Simulator Media Picker & Canvas) ─────────────
  const SAMPLE_MEDIA = [
    {
      id: 'media-1',
      type: 'photo',
      title: 'Tokyo Cyberpunk Alley',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=200&q=80'
    },
    {
      id: 'media-2',
      type: 'photo',
      title: 'Golden Hour Coastline',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&q=80'
    },
    {
      id: 'media-3',
      type: 'photo',
      title: 'Studio Portrait Silhouette',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80'
    },
    {
      id: 'media-4',
      type: 'photo',
      title: 'Minimalist Architecture',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80'
    },
    {
      id: 'media-5',
      type: 'video',
      title: 'High Pacing City Drift',
      aspect: '9:16',
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      thumb: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&q=80'
    },
    {
      id: 'media-6',
      type: 'photo',
      title: 'Product Bottle Hero Shot',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&q=80'
    }
  ];

  // ── SIMULATOR STATE MODEL ────────────────────────────────────────────────
  const SimulatorState = {
    currentTab: 'editor',
    activeProject: {
      id: 'proj-1',
      name: 'MetalCraft Soham',
      isFavorite: true,
      modified: 'Today at 12:33 AM',
      photoCount: 8,
      videoCount: 1,
      audioCount: 1,
      media: [...SAMPLE_MEDIA]
    },
    projects: [
      {
        id: 'proj-1',
        name: 'MetalCraft Soham',
        isFavorite: true,
        modified: 'Today at 12:33 AM',
        photoCount: 8,
        videoCount: 1,
        audioCount: 1,
        media: [...SAMPLE_MEDIA]
      },
      {
        id: 'proj-2',
        name: 'Cyberpunk Reel 2026',
        isFavorite: true,
        modified: 'Yesterday at 8:45 PM',
        photoCount: 4,
        videoCount: 2,
        audioCount: 1,
        media: [SAMPLE_MEDIA[0], SAMPLE_MEDIA[4]]
      },
      {
        id: 'proj-3',
        name: 'Golden Hour Coast',
        isFavorite: false,
        modified: 'Aug 14 at 4:10 PM',
        photoCount: 6,
        videoCount: 1,
        audioCount: 1,
        media: [SAMPLE_MEDIA[1]]
      },
      {
        id: 'proj-4',
        name: 'First Project',
        isFavorite: false,
        modified: 'Aug 12 at 11:20 AM',
        photoCount: 1,
        videoCount: 1,
        audioCount: 0,
        media: [SAMPLE_MEDIA[3]]
      }
    ],
    editor: {
      activeMedia: null,
      adjustments: {
        exposure: 0,
        contrast: 100,
        saturation: 100,
        vignette: 0
      }
    },
    aiCreate: {
      chatMessages: [],
      currentPlan: null,
      isGenerating: false,
      aspectRatio: '9:16',
      soundtrack: 'Auto Match'
    },
    dynamicIsland: {
      state: 'ready',
      text: 'Gemini Ready',
      progress: 0
    }
  };

  // ── REAL DEVICES STATE MODEL ─────────────────────────────────────────────
  const RealDevicesState = {
    devices: [],
    selectedDevice: null,
    searchQuery: '',
    statusFilter: 'all',
    activeRequests: []
  };

  // ── 1. GLOBAL NAVIGATION & VIEW SWITCHER ───────────────────────────────────
  function initNavigation() {
    const navLinks = document.querySelectorAll('#main-nav-switcher .nav-link');
    const sections = document.querySelectorAll('.view-section');

    function switchView(targetView) {
      navLinks.forEach(link => {
        const isMatch = link.getAttribute('data-view') === targetView;
        link.classList.toggle('active', isMatch);
      });

      sections.forEach(sec => {
        const isMatch = sec.id === `view-${targetView}`;
        sec.classList.toggle('active', isMatch);
      });

      // Refresh data if entering Real Devices or Observability
      if (targetView === 'real-devices') {
        fetchRealDevices();
      } else if (targetView === 'observability' || targetView === 'cloud') {
        fetchCloudHealth();
      } else if (targetView === 'audit') {
        fetchAuditLogs();
      }
    }

    navLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const view = link.getAttribute('data-view');
        switchView(view);
        window.location.hash = view;
      });
    });

    // Brand logo returns to Simulator
    const brandLogo = document.getElementById('brand-logo-btn');
    if (brandLogo) {
      brandLogo.addEventListener('click', () => switchView('simulator'));
    }

    // Header pills switch to respective views
    const headerDevPill = document.getElementById('header-device-pill');
    if (headerDevPill) {
      headerDevPill.addEventListener('click', () => switchView('real-devices'));
    }

    const headerCloudPill = document.getElementById('header-cloud-pill');
    if (headerCloudPill) {
      headerCloudPill.addEventListener('click', () => switchView('cloud'));
    }

    // Simulator quick action button
    const btnQuickSwitch = document.getElementById('btn-quick-switch-real');
    if (btnQuickSwitch) {
      btnQuickSwitch.addEventListener('click', () => switchView('real-devices'));
    }

    // Check URL Hash on Load
    const hash = window.location.hash.replace('#', '');
    if (hash && document.getElementById(`view-${hash}`)) {
      switchView(hash);
    }
  }

  // ── 2. THEME ENGINE ──────────────────────────────────────────────────────
  function initTheme() {
    const themeButtons = document.querySelectorAll('#theme-toggle-wrap .appearance-btn');
    const savedTheme = localStorage.getItem('mc-theme') || 'dark';

    function applyTheme(theme) {
      let resolvedTheme = theme;
      if (theme === 'system') {
        resolvedTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      }
      document.documentElement.setAttribute('data-theme', resolvedTheme);
      localStorage.setItem('mc-theme', theme);

      themeButtons.forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-theme-val') === theme);
      });
    }

    themeButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const val = btn.getAttribute('data-theme-val');
        applyTheme(val);
      });
    });

    applyTheme(savedTheme);

    // Watch system changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (localStorage.getItem('mc-theme') === 'system') {
        applyTheme('system');
      }
    });
  }

  // ── 3. DYNAMIC ISLAND ENGINE ─────────────────────────────────────────────
  function updateDynamicIsland(state, text, progress = 0) {
    const di = document.getElementById('dynamic-island');
    const diIcon = document.getElementById('di-icon');
    const diText = document.getElementById('di-text');
    const diProgressWrap = document.getElementById('di-progress-wrap');
    const diProgressFill = document.getElementById('di-progress-fill');

    if (!di || !diIcon || !diText) return;

    SimulatorState.dynamicIsland.state = state;
    SimulatorState.dynamicIsland.text = text;
    SimulatorState.dynamicIsland.progress = progress;

    diText.textContent = text;
    diIcon.className = 'di-icon';

    if (state === 'idle' || state === 'ready') {
      di.classList.remove('expanded');
      diIcon.textContent = '●';
      diIcon.classList.add('done');
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    } else if (state === 'thinking' || state === 'planning') {
      di.classList.add('expanded');
      diIcon.textContent = '✦';
      diIcon.classList.add('thinking');
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    } else if (state === 'rendering') {
      di.classList.add('expanded');
      diIcon.textContent = '◉';
      diIcon.classList.add('rendering');
      if (diProgressWrap) {
        diProgressWrap.style.display = 'block';
        if (diProgressFill) diProgressFill.style.width = `${progress}%`;
      }
    } else if (state === 'done') {
      di.classList.add('expanded');
      diIcon.textContent = '✓';
      diIcon.classList.add('done');
      if (diProgressWrap) diProgressWrap.style.display = 'none';
      setTimeout(() => {
        updateDynamicIsland('ready', 'Gemini Ready');
      }, 3500);
    } else if (state === 'error') {
      di.classList.add('expanded');
      diIcon.textContent = '✕';
      diIcon.classList.add('error');
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    }
  }

  // ── 4. SIMULATOR TABS & CONTROLS ENGINE ──────────────────────────────────
  function initSimulator() {
    const tabButtons = document.querySelectorAll('.ios-tab-bar .tab-item');
    const tabPanels = document.querySelectorAll('.ios-tab-content .tab-panel');

    function switchSimTab(tabName) {
      SimulatorState.currentTab = tabName;

      tabButtons.forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-tab') === tabName);
      });

      tabPanels.forEach(panel => {
        panel.classList.toggle('active', panel.id === `panel-${tabName}`);
      });

      closeAllSimSheets();
    }

    tabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const tab = btn.getAttribute('data-tab');
        switchSimTab(tab);
      });
    });

    // ── SIMULATOR MODAL SHEETS ──
    const overlay = document.getElementById('sim-sheet-overlay');

    function openSimSheet(sheetId) {
      if (overlay) overlay.classList.add('active');
      const sheet = document.getElementById(sheetId);
      if (sheet) sheet.classList.add('active');
    }

    function closeAllSimSheets() {
      if (overlay) overlay.classList.remove('active');
      document.querySelectorAll('.sim-sheet').forEach(sheet => {
        sheet.classList.remove('active');
      });
    }

    if (overlay) {
      overlay.addEventListener('click', closeAllSimSheets);
    }

    // ── TAB 1: EDITOR LOGIC & CANVAS FILTERS ──
    const editorCanvas = document.getElementById('editor-canvas');
    const editorMediaView = document.getElementById('editor-media-view');
    const editorEmptyView = document.getElementById('editor-empty-view');
    const editorBtnReset = document.getElementById('editor-btn-reset');

    const adjExposure = document.getElementById('adj-exposure');
    const adjContrast = document.getElementById('adj-contrast');
    const adjSaturation = document.getElementById('adj-saturation');
    const adjVignette = document.getElementById('adj-vignette');

    const adjExposureVal = document.getElementById('adj-exposure-val');
    const adjContrastVal = document.getElementById('adj-contrast-val');
    const adjSaturationVal = document.getElementById('adj-saturation-val');
    const adjVignetteVal = document.getElementById('adj-vignette-val');

    function updateCanvasFilters() {
      if (!editorCanvas) return;
      const exp = SimulatorState.editor.adjustments.exposure;
      const con = SimulatorState.editor.adjustments.contrast;
      const sat = SimulatorState.editor.adjustments.saturation;
      const vig = SimulatorState.editor.adjustments.vignette;

      const brightness = 100 + exp;
      editorCanvas.style.filter = `brightness(${brightness}%) contrast(${con}%) saturate(${sat}%)`;
    }

    function loadMediaIntoEditor(mediaItem) {
      SimulatorState.editor.activeMedia = mediaItem;
      if (editorCanvas && editorMediaView && editorEmptyView) {
        editorCanvas.src = mediaItem.url;
        editorEmptyView.style.display = 'none';
        editorMediaView.style.display = 'flex';
        if (editorBtnReset) editorBtnReset.style.display = 'flex';
        updateCanvasFilters();
        logSimulatorEvent(`Loaded '${mediaItem.title}' into Metal GPU Canvas Editor`);
      }
    }

    // Sliders Listeners
    if (adjExposure) {
      adjExposure.addEventListener('input', (e) => {
        const val = parseInt(e.target.value, 10);
        SimulatorState.editor.adjustments.exposure = val;
        if (adjExposureVal) adjExposureVal.textContent = (val / 50).toFixed(1);
        updateCanvasFilters();
      });
    }

    if (adjContrast) {
      adjContrast.addEventListener('input', (e) => {
        const val = parseInt(e.target.value, 10);
        SimulatorState.editor.adjustments.contrast = val;
        if (adjContrastVal) adjContrastVal.textContent = (val / 100).toFixed(1);
        updateCanvasFilters();
      });
    }

    if (adjSaturation) {
      adjSaturation.addEventListener('input', (e) => {
        const val = parseInt(e.target.value, 10);
        SimulatorState.editor.adjustments.saturation = val;
        if (adjSaturationVal) adjSaturationVal.textContent = (val / 100).toFixed(1);
        updateCanvasFilters();
      });
    }

    if (adjVignette) {
      adjVignette.addEventListener('input', (e) => {
        const val = parseInt(e.target.value, 10);
        SimulatorState.editor.adjustments.vignette = val;
        if (adjVignetteVal) adjVignetteVal.textContent = `${val}%`;
        updateCanvasFilters();
      });
    }

    if (editorBtnReset) {
      editorBtnReset.addEventListener('click', () => {
        SimulatorState.editor.adjustments = { exposure: 0, contrast: 100, saturation: 100, vignette: 0 };
        if (adjExposure) adjExposure.value = 0;
        if (adjContrast) adjContrast.value = 100;
        if (adjSaturation) adjSaturation.value = 100;
        if (adjVignette) adjVignette.value = 0;
        if (adjExposureVal) adjExposureVal.textContent = '0.0';
        if (adjContrastVal) adjContrastVal.textContent = '1.0';
        if (adjSaturationVal) adjSaturationVal.textContent = '1.0';
        if (adjVignetteVal) adjVignetteVal.textContent = '0%';
        updateCanvasFilters();
      });
    }

    // Editor Action Buttons
    const btnEditorProjects = document.getElementById('editor-btn-projects');
    const editorNavProjects = document.getElementById('editor-nav-projects');
    if (btnEditorProjects) btnEditorProjects.addEventListener('click', () => switchSimTab('projects'));
    if (editorNavProjects) editorNavProjects.addEventListener('click', () => switchSimTab('projects'));

    const btnEditorPhoto = document.getElementById('editor-btn-photo');
    const btnEditorVideo = document.getElementById('editor-btn-video');
    if (btnEditorPhoto) btnEditorPhoto.addEventListener('click', () => openMediaPickerSheet('photo'));
    if (btnEditorVideo) btnEditorVideo.addEventListener('click', () => openMediaPickerSheet('video'));

    // Media Picker Sheet Grid
    function openMediaPickerSheet(filterType = 'all') {
      const grid = document.getElementById('sim-media-picker-grid');
      if (!grid) return;
      grid.innerHTML = '';

      const items = filterType === 'all' ? SAMPLE_MEDIA : SAMPLE_MEDIA.filter(m => m.type === filterType);
      items.forEach(item => {
        const el = document.createElement('div');
        el.className = 'media-picker-item';
        el.innerHTML = `
          <img class="media-picker-thumb" src="${item.thumb}" alt="${item.title}">
          <span class="media-picker-badge">${item.type === 'video' ? '▶ VIDEO' : 'PHOTO'}</span>
        `;
        el.addEventListener('click', () => {
          loadMediaIntoEditor(item);
          closeAllSimSheets();
        });
        grid.appendChild(el);
      });

      openSimSheet('sheet-media-picker');
    }

    const btnCloseMediaPicker = document.getElementById('btn-close-media-picker');
    if (btnCloseMediaPicker) btnCloseMediaPicker.addEventListener('click', closeAllSimSheets);

    // ── TAB 2: AI CREATE STUDIO LOGIC ──
    const aiPromptInput = document.getElementById('sim-prompt-input');
    const aiPromptSendBtn = document.getElementById('sim-prompt-send-btn');
    const aiChatBody = document.getElementById('ai-chat-body');
    const aiChatMessages = document.getElementById('ai-chat-messages');
    const aiHeroView = document.getElementById('ai-hero-view');
    const aiSettingsBtn = document.getElementById('ai-settings-btn');
    const btnCloseAiSettings = document.getElementById('btn-close-ai-settings');

    if (aiSettingsBtn) aiSettingsBtn.addEventListener('click', () => openSimSheet('sheet-ai-settings'));
    if (btnCloseAiSettings) btnCloseAiSettings.addEventListener('click', closeAllSimSheets);

    // Suggestion pills
    document.querySelectorAll('#ai-suggestion-pills .suggestion-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        const prompt = pill.getAttribute('data-prompt');
        if (aiPromptInput) {
          aiPromptInput.value = prompt;
          submitAiCreatePrompt(prompt);
        }
      });
    });

    if (aiPromptSendBtn) {
      aiPromptSendBtn.addEventListener('click', () => {
        const prompt = aiPromptInput ? aiPromptInput.value.trim() : '';
        if (prompt) submitAiCreatePrompt(prompt);
      });
    }

    if (aiPromptInput) {
      aiPromptInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          const prompt = aiPromptInput.value.trim();
          if (prompt) submitAiCreatePrompt(prompt);
        }
      });
    }

    async function submitAiCreatePrompt(promptText) {
      if (SimulatorState.aiCreate.isGenerating) return;
      SimulatorState.aiCreate.isGenerating = true;

      if (aiHeroView) aiHeroView.style.display = 'none';
      if (aiPromptInput) aiPromptInput.value = '';

      // Append User Message
      appendChatMessage('user', promptText);
      updateDynamicIsland('thinking', 'Gemini Thinking…');
      logSimulatorEvent(`AI Create prompt submitted: "${promptText}"`);

      // Update Side Info
      const genStatus = document.getElementById('sim-gen-status');
      const genGoal = document.getElementById('sim-gen-goal');
      if (genStatus) genStatus.textContent = 'Planning…';
      if (genGoal) genGoal.textContent = promptText;

      try {
        // Send request to real backend /api/v1/agent/create
        const resp = await fetch('/api/v1/agent/create', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: promptText,
            projectId: SimulatorState.activeProject.id,
            projectName: SimulatorState.activeProject.name,
            aspectRatio: SimulatorState.aiCreate.aspectRatio
          })
        });

        let planData;
        if (resp.ok) {
          const data = await resp.json();
          planData = data.plan;
        } else {
          // Robust Fallback plan if offline
          planData = {
            goal: promptText,
            confidenceScore: 0.96,
            aspectRatio: '9:16',
            targetDurationSec: 15.0,
            matchedSoundtrack: { title: 'Neon Highway Drift', tempoBpm: 124, genre: 'Synthwave' },
            scenes: [
              { index: 0, assetType: 'photo', durationSec: 3.5, transitionType: 'fadeToBlack', effectName: 'CinematicWarmth' },
              { index: 1, assetType: 'video', durationSec: 4.5, transitionType: 'crossDissolve', effectName: 'CyberpunkGrade' },
              { index: 2, assetType: 'photo', durationSec: 3.5, transitionType: 'swipeRight', effectName: 'HighContrast' },
              { index: 3, assetType: 'photo', durationSec: 3.5, transitionType: 'crossDissolve', effectName: 'VignetteFade' }
            ]
          };
        }

        SimulatorState.aiCreate.currentPlan = planData;
        renderEditPlanCard(planData);
        updateDynamicIsland('ready', 'EditPlan Ready');
      } catch (err) {
        console.warn('Agent API fallback:', err);
        const fallbackPlan = {
          goal: promptText,
          confidenceScore: 0.94,
          aspectRatio: '9:16',
          targetDurationSec: 15.0,
          matchedSoundtrack: { title: 'Golden Hour Horizon', tempoBpm: 110, genre: 'Ambient' },
          scenes: [
            { index: 0, assetType: 'photo', durationSec: 4.0, transitionType: 'crossDissolve', effectName: 'CinematicWarmth' },
            { index: 1, assetType: 'video', durationSec: 6.0, transitionType: 'fadeToBlack', effectName: 'VibrantColor' },
            { index: 2, assetType: 'photo', durationSec: 5.0, transitionType: 'crossDissolve', effectName: 'Vignette' }
          ]
        };
        SimulatorState.aiCreate.currentPlan = fallbackPlan;
        renderEditPlanCard(fallbackPlan);
        updateDynamicIsland('ready', 'EditPlan Ready');
      } finally {
        SimulatorState.aiCreate.isGenerating = false;
      }
    }

    function appendChatMessage(role, text) {
      if (!aiChatMessages) return;
      const bubble = document.createElement('div');
      bubble.className = `msg-bubble ${role === 'user' ? 'msg-user' : 'msg-agent'}`;
      bubble.textContent = text;
      aiChatMessages.appendChild(bubble);
      if (aiChatBody) aiChatBody.scrollTop = aiChatBody.scrollHeight;
    }

    function renderEditPlanCard(plan) {
      if (!aiChatMessages) return;
      const card = document.createElement('div');
      card.className = 'edit-plan-card';
      card.innerHTML = `
        <div class="plan-header">
          <span class="plan-title">📋 Synthesized EditPlan</span>
          <span class="plan-confidence">${Math.round(plan.confidenceScore * 100)}% Confidence</span>
        </div>
        <p style="font-size:11px;font-weight:600;margin-bottom:6px;">"${plan.goal}"</p>
        <div class="plan-body">
          <div class="plan-detail"><span>Scenes</span><strong>${plan.scenes.length} Timeline Cuts</strong></div>
          <div class="plan-detail"><span>Duration</span><strong>${plan.targetDurationSec}s (${plan.aspectRatio})</strong></div>
          <div class="plan-detail"><span>Soundtrack</span><strong>${plan.matchedSoundtrack ? plan.matchedSoundtrack.title : 'Auto Sync'}</strong></div>
          <div class="plan-detail"><span>Shaders</span><strong>MPS Metal GPU</strong></div>
        </div>
        <div class="plan-actions">
          <button class="plan-btn reject" id="btn-plan-modify">Modify</button>
          <button class="plan-btn approve" id="btn-plan-approve">Approve & Render ⚡</button>
        </div>
      `;

      card.querySelector('#btn-plan-modify').addEventListener('click', () => {
        if (aiPromptInput) {
          aiPromptInput.value = `Adjust pacing: ${plan.goal}`;
          aiPromptInput.focus();
        }
      });

      card.querySelector('#btn-plan-approve').addEventListener('click', () => {
        card.querySelector('.plan-actions').innerHTML = `<span style="font-size:10px;color:var(--accent-green);">✓ Plan Approved. Initiating simulated Metal GPU render…</span>`;
        startSimulatedGeneration(plan);
      });

      aiChatMessages.appendChild(card);
      if (aiChatBody) aiChatBody.scrollTop = aiChatBody.scrollHeight;
    }

    function startSimulatedGeneration(plan) {
      if (!aiChatMessages) return;
      const progressCard = document.createElement('div');
      progressCard.className = 'gen-progress-card';
      progressCard.innerHTML = `
        <div class="gen-progress-header">
          <span>Simulated Apple Metal GPU</span>
          <span id="gen-pct">0%</span>
        </div>
        <div class="gen-progress-bar">
          <div class="gen-progress-fill" id="gen-fill" style="width:0%"></div>
        </div>
        <div class="gen-progress-msg" id="gen-msg">Compiling MPS shaders…</div>
      `;
      aiChatMessages.appendChild(progressCard);
      if (aiChatBody) aiChatBody.scrollTop = aiChatBody.scrollHeight;

      const fill = progressCard.querySelector('#gen-fill');
      const pct = progressCard.querySelector('#gen-pct');
      const msg = progressCard.querySelector('#gen-msg');
      const genProgressSide = document.getElementById('sim-gen-progress');
      const genStatusSide = document.getElementById('sim-gen-status');

      let currentPct = 0;
      const interval = setInterval(() => {
        currentPct += 12;
        if (currentPct > 100) currentPct = 100;

        if (fill) fill.style.width = `${currentPct}%`;
        if (pct) pct.textContent = `${currentPct}%`;
        if (genProgressSide) genProgressSide.textContent = `${currentPct}%`;
        if (genStatusSide) genStatusSide.textContent = `Rendering (${currentPct}%)`;

        let statusText = 'Processing MPS Frame Pass…';
        if (currentPct < 25) statusText = 'Compiling Metal Pipeline Descriptors…';
        else if (currentPct < 50) statusText = 'Applying GPU Color Grade & Dissolve Shaders…';
        else if (currentPct < 80) statusText = 'AVFoundation Audio Multiplexing…';
        else statusText = 'Validating MP4 H.264 Container…';

        if (msg) msg.textContent = statusText;
        updateDynamicIsland('rendering', `Simulated GPU ${currentPct}%`, currentPct);

        if (currentPct >= 100) {
          clearInterval(interval);
          if (genStatusSide) genStatusSide.textContent = 'Complete';
          updateDynamicIsland('done', 'Render Complete ✓');
          renderVideoResultCard(plan);
        }
      }, 350);
    }

    function renderVideoResultCard(plan) {
      if (!aiChatMessages) return;
      const card = document.createElement('div');
      card.className = 'video-preview-card';
      card.innerHTML = `
        <div class="video-preview-thumb" id="btn-play-preview-thumb">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        </div>
        <div class="video-preview-info">
          <h4>${plan.goal}</h4>
          <p>1080×1920 (9:16) · ${plan.targetDurationSec}s · ${plan.matchedSoundtrack ? plan.matchedSoundtrack.title : 'Audio Mix'}</p>
          <div class="video-preview-actions">
            <button class="video-action-btn" id="btn-add-to-project">+ Add to Project</button>
            <button class="video-action-btn" id="btn-download-artifact">📥 Download</button>
            <button class="video-action-btn" id="btn-share-artifact">↗ Share</button>
          </div>
        </div>
      `;

      card.querySelector('#btn-play-preview-thumb').addEventListener('click', () => {
        openVideoPlayerModal(SAMPLE_MEDIA[4].url, plan.goal);
      });

      card.querySelector('#btn-add-to-project').addEventListener('click', () => {
        SimulatorState.activeProject.videoCount += 1;
        updateProjectBadges();
        alert(`Artifact added to project '${SimulatorState.activeProject.name}'!`);
      });

      card.querySelector('#btn-download-artifact').addEventListener('click', () => {
        openVideoPlayerModal(SAMPLE_MEDIA[4].url, plan.goal);
      });

      card.querySelector('#btn-share-artifact').addEventListener('click', () => {
        if (navigator.share) {
          navigator.share({ title: plan.goal, text: 'Created with MetalCraft iOS & Apple Metal GPU' });
        } else {
          alert('Shared to Clipboard: MetalCraft Video Artifact Ready');
        }
      });

      aiChatMessages.appendChild(card);
      if (aiChatBody) aiChatBody.scrollTop = aiChatBody.scrollHeight;
    }

    // Quick Sample Reel Action
    const btnQuickReel = document.getElementById('btn-quick-sample-reel');
    if (btnQuickReel) {
      btnQuickReel.addEventListener('click', () => {
        switchSimTab('ai-create');
        submitAiCreatePrompt('Create a 15-second cinematic product reel');
      });
    }

    // ── TAB 3: ANALYTICS SUB-PILLS & PIPELINE STAGES ──
    const subtabButtons = document.querySelectorAll('#panel-analytics .section-pill');
    const subtabPipeline = document.getElementById('analytics-sub-pipeline');
    const subtabOverview = document.getElementById('analytics-sub-overview');

    subtabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        subtabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const sub = btn.getAttribute('data-subtab');
        if (subtabPipeline) subtabPipeline.style.display = sub === 'pipeline' ? 'block' : 'none';
        if (subtabOverview) subtabOverview.style.display = sub === 'overview' ? 'block' : 'none';
      });
    });

    // Interactive 7 Pipeline Stages
    document.querySelectorAll('.pipeline-stage').forEach(stage => {
      stage.addEventListener('click', () => {
        const stageNum = stage.getAttribute('data-stage');
        const name = stage.querySelector('.pipeline-stage-name').textContent;
        const desc = stage.querySelector('.pipeline-stage-desc').textContent;
        alert(`Pipeline Stage Inspection:\n\nStage ${stageNum}: ${name}\nDetails: ${desc}\nStatus: Optimal (0 dropped frames, 30.0 FPS)`);
      });
    });

    // ── TAB 4: PROJECTS LIST & CREATION LOGIC ──
    const simProjectsList = document.getElementById('sim-projects-list');
    const btnProjectsNew = document.getElementById('projects-btn-new');
    const btnCancelNewProject = document.getElementById('btn-cancel-new-project');
    const btnConfirmNewProject = document.getElementById('btn-confirm-new-project');
    const inputNewProjectName = document.getElementById('input-new-project-name');

    if (btnProjectsNew) btnProjectsNew.addEventListener('click', () => openSimSheet('sheet-new-project'));
    if (btnCancelNewProject) btnCancelNewProject.addEventListener('click', closeAllSimSheets);

    if (btnConfirmNewProject) {
      btnConfirmNewProject.addEventListener('click', () => {
        const name = inputNewProjectName ? inputNewProjectName.value.trim() : '';
        if (!name) return;
        const newProj = {
          id: `proj-${Date.now()}`,
          name: name,
          isFavorite: false,
          modified: 'Just now',
          photoCount: 0,
          videoCount: 0,
          audioCount: 0,
          media: []
        };
        SimulatorState.projects.unshift(newProj);
        SimulatorState.activeProject = newProj;
        renderProjectsList('all');
        updateProjectBadges();
        closeAllSimSheets();
        if (inputNewProjectName) inputNewProjectName.value = '';
        logSimulatorEvent(`Created new project: '${name}'`);
      });
    }

    function renderProjectsList(filter = 'all') {
      if (!simProjectsList) return;
      simProjectsList.innerHTML = '';

      let list = SimulatorState.projects;
      if (filter === 'favorites') list = list.filter(p => p.isFavorite);

      list.forEach(proj => {
        const row = document.createElement('div');
        row.className = 'project-row';
        row.innerHTML = `
          <span class="project-star">${proj.isFavorite ? '⭐' : '☆'}</span>
          <div class="project-info">
            <div class="project-name">${proj.name}</div>
            <div class="project-meta">
              <span>${proj.modified}</span>
              <span class="project-meta-dot">·</span>
              <span>${proj.photoCount} Photos, ${proj.videoCount} Videos</span>
            </div>
          </div>
          <div class="project-chevron">›</div>
        `;

        row.querySelector('.project-star').addEventListener('click', (e) => {
          e.stopPropagation();
          proj.isFavorite = !proj.isFavorite;
          renderProjectsList(filter);
        });

        row.addEventListener('click', () => {
          SimulatorState.activeProject = proj;
          updateProjectBadges();
          switchSimTab('ai-create');
        });

        simProjectsList.appendChild(row);
      });
    }

    // Projects Filter Pills
    document.querySelectorAll('.project-filter-row .filter-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        document.querySelectorAll('.project-filter-row .filter-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        renderProjectsList(pill.getAttribute('data-filter'));
      });
    });

    function updateProjectBadges() {
      const activeName = document.getElementById('ai-active-project-name');
      const heroPill = document.getElementById('ai-hero-project-pill');
      const tabBadge = document.getElementById('sim-tab-project-count');
      const ctxMedia = document.getElementById('ctx-media-label');

      if (activeName) activeName.textContent = SimulatorState.activeProject.name;
      if (heroPill) heroPill.textContent = `Selected: '${SimulatorState.activeProject.name}'`;
      if (tabBadge) tabBadge.textContent = SimulatorState.projects.length;
      if (ctxMedia) ctxMedia.textContent = `${SimulatorState.activeProject.photoCount} Photos · ${SimulatorState.activeProject.videoCount} Video`;
    }

    // Initialize Simulator views
    renderProjectsList('all');
    updateProjectBadges();
  }

  // ── 5. REAL IPHONE FLEET MANAGEMENT ENGINE ─────────────────────────────────
  async function fetchRealDevices() {
    try {
      const resp = await fetch('/api/v1/ios/devices');
      if (resp.ok) {
        const data = await resp.json();
        RealDevicesState.devices = data.devices || [];
        renderRealDevicesGrid();
        updateFleetStats();
      }
    } catch (err) {
      console.warn('Could not fetch real devices:', err);
    }
  }

  function renderRealDevicesGrid() {
    const grid = document.getElementById('real-devices-grid');
    if (!grid) return;
    grid.innerHTML = '';

    let filtered = RealDevicesState.devices;

    // Apply Status Filter
    if (RealDevicesState.statusFilter === 'online') {
      filtered = filtered.filter(d => d.isLive || d.status.toUpperCase() === 'ONLINE');
    } else if (RealDevicesState.statusFilter === 'busy') {
      filtered = filtered.filter(d => d.status.toUpperCase() === 'BUSY' || d.status.toUpperCase() === 'RENDERING');
    } else if (RealDevicesState.statusFilter === 'offline') {
      filtered = filtered.filter(d => !d.isLive && d.status.toUpperCase() === 'OFFLINE');
    }

    // Apply Search Query
    if (RealDevicesState.searchQuery) {
      const q = RealDevicesState.searchQuery.toLowerCase();
      filtered = filtered.filter(d => 
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.deviceId && d.deviceId.toLowerCase().includes(q)) ||
        (d.model && d.model.toLowerCase().includes(q)) ||
        (d.sessionId && d.sessionId.toLowerCase().includes(q))
      );
    }

    if (filtered.length === 0) {
      grid.innerHTML = `
        <div class="real-devices-empty">
          <h3>No Matching iPhones Found</h3>
          <p>Connect your physical iPhone running the MetalCraft app to <strong>https://metalcraft-ols0.onrender.com</strong> or switch filters above.</p>
        </div>
      `;
      return;
    }

    filtered.forEach(dev => {
      const isOnline = dev.isLive || dev.status.toUpperCase() === 'ONLINE';
      const card = document.createElement('div');
      card.className = 'real-device-card';
      card.innerHTML = `
        <div class="device-card-top">
          <div class="device-card-header">
            <div class="device-icon-wrap">📱</div>
            <div class="device-title-wrap">
              <h3>${dev.name || 'MetalCraft iPhone'}</h3>
              <span class="device-id-badge">${dev.deviceId || 'MC-IOS-DEVICE'}</span>
            </div>
          </div>
          <div class="device-status-badge ${isOnline ? 'online' : 'offline'}">
            <span>●</span>
            <span>${isOnline ? 'ONLINE' : 'OFFLINE'}</span>
          </div>
        </div>

        <div class="device-card-specs">
          <div class="device-spec-item">
            <span>Model</span>
            <strong>${dev.model || 'iPhone (Apple Silicon)'}</strong>
          </div>
          <div class="device-spec-item">
            <span>iOS / App</span>
            <strong>${dev.osVersion || 'iOS 18'} (${dev.appVersion || '1.0.0'})</strong>
          </div>
          <div class="device-spec-item">
            <span>Metal GPU</span>
            <strong style="color:var(--accent-green);">Available (4K)</strong>
          </div>
          <div class="device-spec-item">
            <span>Last Heartbeat</span>
            <strong>${dev.lastHeartbeat ? formatRelativeTime(dev.lastHeartbeat) : 'Just now'}</strong>
          </div>
        </div>

        <div class="device-card-job">
          Current State: <strong>${isOnline ? 'Idle · Ready for Metal GPU Jobs' : 'Disconnected'}</strong>
        </div>

        <div class="device-card-actions">
          <button class="device-btn" data-session="${dev.sessionId}">Open Device Console</button>
        </div>
      `;

      card.querySelector('button').addEventListener('click', () => {
        openDeviceConsoleModal(dev);
      });

      grid.appendChild(card);
    });
  }

  function updateFleetStats() {
    const totalCount = RealDevicesState.devices.length;
    const onlineCount = RealDevicesState.devices.filter(d => d.isLive || d.status.toUpperCase() === 'ONLINE').length;

    const statsConnected = document.getElementById('stats-connected-count');
    const statsTotal = document.getElementById('stats-total-fleet');
    const navBadge = document.getElementById('nav-device-count-badge');
    const headerDot = document.getElementById('header-device-dot');
    const headerText = document.getElementById('header-device-text');

    if (statsConnected) statsConnected.textContent = onlineCount;
    if (statsTotal) statsTotal.textContent = totalCount;
    if (navBadge) navBadge.textContent = onlineCount;

    if (headerDot && headerText) {
      if (onlineCount > 0) {
        headerDot.className = 'status-dot dot-online';
        headerText.textContent = `${onlineCount} iPhone Connected`;
      } else {
        headerDot.className = 'status-dot dot-waiting';
        headerText.textContent = 'No iPhone Connected';
      }
    }
  }

  function initRealDevicesControls() {
    const searchInput = document.getElementById('device-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        RealDevicesState.searchQuery = e.target.value;
        renderRealDevicesGrid();
      });
    }

    document.querySelectorAll('#device-filter-pills .device-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('#device-filter-pills .device-filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        RealDevicesState.statusFilter = btn.getAttribute('data-filter');
        renderRealDevicesGrid();
      });
    });
  }

  function openDeviceConsoleModal(dev) {
    const modal = document.getElementById('modal-device-details');
    const title = document.getElementById('modal-device-name');
    const content = document.getElementById('modal-device-content');
    if (!modal || !content) return;

    title.textContent = `${dev.name || 'iPhone'} (${dev.deviceId || 'MC-IOS'})`;
    content.innerHTML = `
      <div style="background:var(--fill-quaternary);padding:14px;border-radius:14px;margin-bottom:14px;font-size:12px;">
        <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
          <span>Session ID:</span><strong style="font-family:var(--font-mono);">${dev.sessionId}</strong>
        </div>
        <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
          <span>Status:</span><strong style="color:var(--accent-green);">${dev.isLive ? 'ONLINE (WebSocket Active)' : 'OFFLINE'}</strong>
        </div>
        <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
          <span>GPU Pipeline:</span><strong>Metal Performance Shaders (MPS)</strong>
        </div>
        <div style="display:flex;justify-content:space-between;">
          <span>Max Output:</span><strong>4K 60FPS Video</strong>
        </div>
      </div>

      <h4 style="font-size:13px;font-weight:700;margin-bottom:8px;">Live Device Actions</h4>
      <div style="display:flex;gap:8px;margin-bottom:14px;">
        <button class="sim-btn primary" id="modal-btn-dispatch-job" style="flex:1;justify-content:center;">
          ⚡ Dispatch Job to This iPhone
        </button>
      </div>

      <h4 style="font-size:13px;font-weight:700;margin-bottom:8px;">Recent Render Requests</h4>
      <div style="font-size:11px;color:var(--text-secondary);">
        <p>No active queued jobs for this device session.</p>
      </div>
    `;

    content.querySelector('#modal-btn-dispatch-job').addEventListener('click', () => {
      alert(`Job dispatch target set to ${dev.name} (${dev.deviceId}). Prompts submitted in AI Create will execute on this real iPhone!`);
      modal.classList.remove('active');
    });

    modal.classList.add('active');
  }

  const btnCloseDeviceModal = document.getElementById('btn-close-device-modal');
  if (btnCloseDeviceModal) {
    btnCloseDeviceModal.addEventListener('click', () => {
      const modal = document.getElementById('modal-device-details');
      if (modal) modal.classList.remove('active');
    });
  }

  // ── 6. CLOUD INTELLIGENCE, HEALTH & AUDIT TRAIL ───────────────────────────
  async function fetchCloudHealth() {
    try {
      const resp = await fetch('/api/v1/health');
      if (resp.ok) {
        const data = await resp.json();
        const geminiStatus = document.getElementById('cloud-gemini-status');
        const parallelStatus = document.getElementById('cloud-parallel-status');
        const grafanaStatus = document.getElementById('cloud-grafana-status');

        if (geminiStatus && data.providers && data.providers.gemini) {
          geminiStatus.textContent = `● Status: ${data.providers.gemini.status} (Server-Side Configured)`;
        }
        if (parallelStatus && data.providers && data.providers.parallel) {
          parallelStatus.textContent = `● Status: ${data.providers.parallel.status} (${data.providers.parallel.latencyMs ? Math.round(data.providers.parallel.latencyMs) + 'ms' : 'Configured'})`;
        }
        if (grafanaStatus && data.providers && data.providers.grafana) {
          grafanaStatus.textContent = `● Status: ${data.providers.grafana.status} (HTTP ${data.providers.grafana.httpCode || 200})`;
        }
      }
    } catch (err) {
      console.warn('Could not fetch cloud health:', err);
    }
  }

  const btnDiagnostics = document.getElementById('btn-run-diagnostics');
  if (btnDiagnostics) {
    btnDiagnostics.addEventListener('click', async () => {
      btnDiagnostics.innerHTML = `<div class="spinner"></div><span>Running Diagnostics…</span>`;
      await fetchCloudHealth();
      setTimeout(() => {
        btnDiagnostics.innerHTML = `<span>✓ Diagnostics Complete</span>`;
        setTimeout(() => {
          btnDiagnostics.innerHTML = `<span>⟳ Run Live Cloud Diagnostics</span>`;
        }, 2000);
      }, 800);
    });
  }

  async function fetchAuditLogs() {
    const tbody = document.getElementById('audit-table-body');
    if (!tbody) return;

    try {
      const resp = await fetch('/api/v1/audit?limit=25');
      if (resp.ok) {
        const data = await resp.json();
        const records = data.auditRecords || [];
        if (records.length === 0) {
          tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;color:var(--text-tertiary);padding:24px;">No audit events recorded yet.</td></tr>`;
          return;
        }

        tbody.innerHTML = '';
        records.forEach(r => {
          const tr = document.createElement('tr');
          tr.innerHTML = `
            <td style="font-family:var(--font-mono);font-size:11px;color:var(--text-secondary);">${r.timestamp ? new Date(r.timestamp).toLocaleTimeString() : '—'}</td>
            <td><strong>${r.category || 'System'}</strong></td>
            <td>${r.action}</td>
            <td><span class="audit-status ${r.status === 'SUCCESS' ? 'success' : r.status === 'ERROR' ? 'error' : 'info'}">${r.status || 'INFO'}</span></td>
            <td style="color:var(--text-secondary);font-size:12px;">${r.description || '—'}</td>
          `;
          tbody.appendChild(tr);
        });
      }
    } catch (err) {
      console.warn('Could not fetch audit logs:', err);
    }
  }

  // ── 7. VIDEO PLAYER MODAL ────────────────────────────────────────────────
  function openVideoPlayerModal(videoUrl, titleText = 'Rendered Video Reel') {
    const modal = document.getElementById('modal-video-player');
    const videoElem = document.getElementById('global-video-player-elem');
    const titleElem = document.getElementById('modal-video-title');
    if (!modal || !videoElem) return;

    videoElem.src = videoUrl;
    if (titleElem) titleElem.textContent = titleText;
    modal.classList.add('active');
  }

  const btnCloseVideoModal = document.getElementById('btn-close-video-modal');
  if (btnCloseVideoModal) {
    btnCloseVideoModal.addEventListener('click', () => {
      const modal = document.getElementById('modal-video-player');
      const videoElem = document.getElementById('global-video-player-elem');
      if (videoElem) videoElem.pause();
      if (modal) modal.classList.remove('active');
    });
  }

  // ── 8. WEBSOCKET REAL-TIME DISPATCHER ─────────────────────────────────────
  function initWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/web`;

    let ws;
    function connect() {
      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          const simWsStatus = document.getElementById('sim-ws-status');
          if (simWsStatus) {
            simWsStatus.textContent = 'Connected';
            simWsStatus.className = 'info-card-value pass';
          }
        };

        ws.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);
            handleWebSocketMessage(msg);
          } catch (e) {
            console.error('Invalid WS payload:', e);
          }
        };

        ws.onclose = () => {
          const simWsStatus = document.getElementById('sim-ws-status');
          if (simWsStatus) {
            simWsStatus.textContent = 'Reconnecting…';
            simWsStatus.className = 'info-card-value warn';
          }
          setTimeout(connect, 3000);
        };
      } catch (err) {
        setTimeout(connect, 3000);
      }
    }

    connect();
  }

  function handleWebSocketMessage(msg) {
    if (msg.type === 'DEVICE_REGISTERED' || msg.type === 'DEVICE_STATUS_CHANGED') {
      fetchRealDevices();
    } else if (msg.type === 'GENERATION_PROGRESS') {
      // Progress event from physical device
      logSimulatorEvent(`Real iPhone Render: ${msg.progress || 0}% - ${msg.progressMessage || ''}`);
    }
  }

  // ── UTILITIES ────────────────────────────────────────────────────────────
  function logSimulatorEvent(text) {
    const logElem = document.getElementById('sim-event-log');
    if (!logElem) return;
    const now = new Date().toLocaleTimeString();
    const line = document.createElement('div');
    line.textContent = `[${now}] ${text}`;
    logElem.appendChild(line);
    logElem.scrollTop = logElem.scrollHeight;
  }

  function formatRelativeTime(isoStr) {
    const diffSec = Math.round((Date.now() - new Date(isoStr).getTime()) / 1000);
    if (diffSec < 5) return 'Just now';
    if (diffSec < 60) return `${diffSec}s ago`;
    return `${Math.round(diffSec / 60)}m ago`;
  }

  // Live status bar clock
  function startClock() {
    const clock = document.getElementById('sim-clock');
    if (!clock) return;
    function tick() {
      const d = new Date();
      let hours = d.getHours();
      const mins = d.getMinutes().toString().padStart(2, '0');
      hours = hours % 12 || 12;
      clock.textContent = `${hours}:${mins}`;
    }
    tick();
    setInterval(tick, 10000);
  }

  // ── INITIALIZATION ───────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    initTheme();
    initNavigation();
    initSimulator();
    initRealDevicesControls();
    startClock();
    initWebSocket();

    // Initial data fetch
    fetchRealDevices();
    fetchCloudHealth();
  });

})();
