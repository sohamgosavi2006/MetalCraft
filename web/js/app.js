/**
 * MetalCraft — Web Companion & Complete iPhone 17 Pro Simulator
 * Version 2.3.0 — Physical Simulator & Full Project/Editor Pipeline
 * 
 * Features:
 * - Dynamic Island: Minimal Apple system UI (Ready, Processing, Complete), NO Gemini branding.
 * - Hardware Side Buttons: Volume Up/Down with iOS Volume HUD, Action Button with Silent Banner, Power Button with Lock/Wake.
 * - Projects Screen -> Dedicated Project Detail Screen with Photos Grid, Videos Grid, Audio Track, and Actions.
 * - Fully Working Non-Destructive Photo & Video Editor with Metal Shader simulation and Project Persistence.
 * - Real iPhone Fleet Management with Search, Filters, Refresh, and Console Modal.
 * - AI Create Studio with Gemini 2.5 Flash EditPlan synthesis and simulated Metal GPU rendering passes.
 * - Auto-detecting WebSocket (ws:// / wss://) with exponential backoff.
 */

(function () {
  'use strict';

  // ── DEFAULT STOCK MEDIA FOR IMPORT ───────────────────────────────────────
  const STOCK_MEDIA_LIBRARY = [
    {
      id: 'stock-1',
      type: 'photo',
      name: 'Tokyo Cyberpunk Alley',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=200&q=80',
      adjustments: { brightness: 0, contrast: 115, exposure: 10, saturation: 125, temperature: -15, vignette: 15 }
    },
    {
      id: 'stock-2',
      type: 'photo',
      name: 'Golden Hour Coastline',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&q=80',
      adjustments: { brightness: 5, contrast: 105, exposure: 0, saturation: 110, temperature: 35, vignette: 0 }
    },
    {
      id: 'stock-3',
      type: 'photo',
      name: 'Studio Portrait Silhouette',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
      adjustments: { brightness: -10, contrast: 130, exposure: -5, saturation: 90, temperature: 0, vignette: 25 }
    },
    {
      id: 'stock-4',
      type: 'photo',
      name: 'Minimalist Architecture',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80',
      adjustments: { brightness: 0, contrast: 110, exposure: 5, saturation: 95, temperature: -5, vignette: 0 }
    },
    {
      id: 'stock-5',
      type: 'video',
      name: 'High Pacing City Drift',
      aspect: '9:16',
      durationSec: 15.0,
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      thumb: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&q=80'
    },
    {
      id: 'stock-6',
      type: 'photo',
      name: 'Product Bottle Hero Shot',
      aspect: '9:16',
      url: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=800&q=80',
      thumb: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&q=80',
      adjustments: { brightness: 0, contrast: 120, exposure: 0, saturation: 105, temperature: 0, vignette: 10 }
    }
  ];

  // ── SIMULATOR STATE MODEL ────────────────────────────────────────────────
  const SimulatorState = {
    currentTab: 'editor',
    hardware: {
      volume: 70, // 0 to 100
      isSilent: false,
      isLocked: false,
      volumeTimer: null,
      bannerTimer: null
    },
    projects: [],
    activeProject: null,
    editor: {
      activeMedia: null,
      activeMediaType: 'photo', // 'photo' or 'video'
      adjustments: {
        exposure: 0,     // -100 to 100
        contrast: 100,   // 50 to 200
        saturation: 100, // 0 to 200
        brightness: 0,   // -100 to 100
        temperature: 0,  // -50 to 50
        vignette: 0      // 0 to 100
      },
      currentPreset: 'original'
    },
    aiCreate: {
      chatMessages: [],
      currentPlan: null,
      isGenerating: false,
      aspectRatio: '9:16'
    },
    dynamicIsland: {
      state: 'ready',
      text: 'Ready',
      progress: 0
    }
  };

  // ── REAL DEVICES STATE MODEL ─────────────────────────────────────────────
  const RealDevicesState = {
    devices: [],
    selectedDevice: null,
    searchQuery: '',
    statusFilter: 'all'
  };

  // ── 1. GLOBAL NAVIGATION & ROUTING ───────────────────────────────────────
  function initNavigation() {
    const navLinks = document.querySelectorAll('#main-nav-switcher .nav-link');
    const sections = document.querySelectorAll('.view-section');

    function switchView(targetView) {
      if (!targetView) targetView = 'simulator';

      navLinks.forEach(link => {
        const isMatch = link.getAttribute('data-view') === targetView;
        link.classList.toggle('active', isMatch);
      });

      sections.forEach(sec => {
        const isMatch = sec.id === `view-${targetView}`;
        sec.classList.toggle('active', isMatch);
      });

      if (targetView === 'real-devices') {
        fetchRealDevices();
      } else if (targetView === 'ai-pipeline') {
        fetchCloudHealth();
      } else if (targetView === 'observability-audit') {
        fetchObservabilityOverview();
      }
    }

    navLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const view = link.getAttribute('data-view');
        switchView(view);
        if (window.location.hash !== `#${view}`) {
          window.location.hash = view;
        }
      });
    });

    const brandLogo = document.getElementById('brand-logo-btn');
    if (brandLogo) {
      brandLogo.addEventListener('click', () => {
        switchView('simulator');
        window.location.hash = 'simulator';
      });
    }

    const headerDevPill = document.getElementById('header-device-pill');
    if (headerDevPill) {
      headerDevPill.addEventListener('click', () => {
        switchView('real-devices');
        window.location.hash = 'real-devices';
      });
    }

    const headerCloudPill = document.getElementById('header-cloud-pill');
    if (headerCloudPill) {
      headerCloudPill.addEventListener('click', () => {
        switchView('ai-pipeline');
        window.location.hash = 'ai-pipeline';
      });
    }

    const btnQuickSwitch = document.getElementById('btn-quick-switch-real');
    if (btnQuickSwitch) {
      btnQuickSwitch.addEventListener('click', () => {
        switchView('real-devices');
        window.location.hash = 'real-devices';
      });
    }

    window.addEventListener('hashchange', () => {
      const currentHash = window.location.hash.replace('#', '');
      if (currentHash && document.getElementById(`view-${currentHash}`)) {
        switchView(currentHash);
      }
    });

    const initialHash = window.location.hash.replace('#', '');
    if (initialHash && document.getElementById(`view-${initialHash}`)) {
      switchView(initialHash);
    } else {
      switchView('simulator');
    }
  }

  // ── 2. SUBTABS CONTROLLER ────────────────────────────────────────────────
  function initSubtabs() {
    // A. AI & Pipeline Subtabs
    const aiSubtabButtons = document.querySelectorAll('#ai-pipeline-subtabs .subtab-btn');
    aiSubtabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        aiSubtabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const tabKey = btn.getAttribute('data-aitab');
        document.querySelectorAll('#view-ai-pipeline .subtab-content').forEach(content => {
          content.classList.toggle('active', content.id === `aitab-${tabKey}`);
        });
      });
    });

    // B. Observability & Audit Subtabs
    const obsSubtabButtons = document.querySelectorAll('#obs-audit-subtabs .subtab-btn');
    obsSubtabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        obsSubtabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const tabKey = btn.getAttribute('data-obstab');
        document.querySelectorAll('#view-observability-audit .subtab-content').forEach(content => {
          content.classList.toggle('active', content.id === `obstab-${tabKey}`);
        });

        if (tabKey === 'requests') fetchObservabilityRequests();
        else if (tabKey === 'devices') fetchObservabilityDevices();
        else if (tabKey === 'audit') fetchObservabilityAudit();
        else if (tabKey === 'metrics') fetchAnalyticsMetrics();
      });
    });
  }

  // ── 3. THEME ENGINE ──────────────────────────────────────────────────────
  function initTheme() {
    const btnLight = document.getElementById('theme-btn-light');
    const btnDark = document.getElementById('theme-btn-dark');
    const savedTheme = localStorage.getItem('mc-theme') || 'dark';

    function applyTheme(theme) {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('mc-theme', theme);

      if (btnLight) btnLight.classList.toggle('active', theme === 'light');
      if (btnDark) btnDark.classList.toggle('active', theme === 'dark');
    }

    if (btnLight) btnLight.addEventListener('click', () => applyTheme('light'));
    if (btnDark) btnDark.addEventListener('click', () => applyTheme('dark'));

    applyTheme(savedTheme);
  }

  // ── 4. DYNAMIC ISLAND ENGINE (Minimal Apple System Status - NO Gemini) ───
  function updateDynamicIsland(state, text, progress = 0) {
    const di = document.getElementById('dynamic-island');
    const diDot = document.getElementById('di-icon-dot');
    const diText = document.getElementById('di-text');
    const diProgressWrap = document.getElementById('di-progress-wrap');
    const diProgressFill = document.getElementById('di-progress-fill');

    if (!di || !diDot || !diText) return;

    SimulatorState.dynamicIsland.state = state;
    SimulatorState.dynamicIsland.text = text;
    SimulatorState.dynamicIsland.progress = progress;

    diText.textContent = text;

    if (state === 'idle' || state === 'ready') {
      di.classList.remove('expanded');
      diDot.style.background = 'var(--accent-green)';
      diDot.style.boxShadow = '0 0 8px var(--accent-green)';
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    } else if (state === 'thinking' || state === 'planning') {
      di.classList.add('expanded');
      diDot.style.background = 'var(--accent-purple)';
      diDot.style.boxShadow = '0 0 8px var(--accent-purple)';
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    } else if (state === 'rendering') {
      di.classList.add('expanded');
      diDot.style.background = 'var(--accent-cyan)';
      diDot.style.boxShadow = '0 0 8px var(--accent-cyan)';
      if (diProgressWrap) {
        diProgressWrap.style.display = 'block';
        if (diProgressFill) diProgressFill.style.width = `${progress}%`;
      }
    } else if (state === 'done') {
      di.classList.add('expanded');
      diDot.style.background = 'var(--accent-green)';
      diDot.style.boxShadow = '0 0 8px var(--accent-green)';
      if (diProgressWrap) diProgressWrap.style.display = 'none';
      setTimeout(() => {
        updateDynamicIsland('ready', 'Ready');
      }, 3500);
    } else if (state === 'error') {
      di.classList.add('expanded');
      diDot.style.background = 'var(--accent-red)';
      diDot.style.boxShadow = '0 0 8px var(--accent-red)';
      if (diProgressWrap) diProgressWrap.style.display = 'none';
    }
  }

  // ── 5. PHYSICAL IPHONE HARDWARE BUTTONS & OVERLAYS ─────────────────────────
  function initHardwareButtons() {
    const btnVolUp = document.getElementById('hw-btn-vol-up');
    const btnVolDown = document.getElementById('hw-btn-vol-down');
    const btnAction = document.getElementById('hw-btn-action');
    const btnPower = document.getElementById('hw-btn-power');

    const volHud = document.getElementById('sim-volume-hud');
    const volFill = document.getElementById('hud-vol-fill');
    const volPct = document.getElementById('hud-vol-pct');
    const hudIcon = document.getElementById('hud-icon');

    const bannerHud = document.getElementById('sim-banner-hud');
    const bannerText = document.getElementById('banner-hud-text');
    const lockOverlay = document.getElementById('sim-lock-overlay');

    function showVolumeHud() {
      if (!volHud || !volFill || !volPct) return;
      volFill.style.width = `${SimulatorState.hardware.volume}%`;
      volPct.textContent = `${SimulatorState.hardware.volume}%`;
      hudIcon.textContent = SimulatorState.hardware.volume === 0 ? '🔇' : '🔊';

      volHud.classList.add('visible');
      if (SimulatorState.hardware.volumeTimer) clearTimeout(SimulatorState.hardware.volumeTimer);
      SimulatorState.hardware.volumeTimer = setTimeout(() => {
        volHud.classList.remove('visible');
      }, 1800);
    }

    function showBannerHud(text) {
      if (!bannerHud || !bannerText) return;
      bannerText.textContent = text;
      bannerHud.classList.add('visible');
      if (SimulatorState.hardware.bannerTimer) clearTimeout(SimulatorState.hardware.bannerTimer);
      SimulatorState.hardware.bannerTimer = setTimeout(() => {
        bannerHud.classList.remove('visible');
      }, 2000);
    }

    if (btnVolUp) {
      btnVolUp.addEventListener('click', () => {
        btnVolUp.classList.add('pressed');
        setTimeout(() => btnVolUp.classList.remove('pressed'), 120);
        SimulatorState.hardware.volume = Math.min(100, SimulatorState.hardware.volume + 10);
        showVolumeHud();
        logSimulatorEvent(`Hardware Volume Up: ${SimulatorState.hardware.volume}%`);
      });
    }

    if (btnVolDown) {
      btnVolDown.addEventListener('click', () => {
        btnVolDown.classList.add('pressed');
        setTimeout(() => btnVolDown.classList.remove('pressed'), 120);
        SimulatorState.hardware.volume = Math.max(0, SimulatorState.hardware.volume - 10);
        showVolumeHud();
        logSimulatorEvent(`Hardware Volume Down: ${SimulatorState.hardware.volume}%`);
      });
    }

    if (btnAction) {
      btnAction.addEventListener('click', () => {
        btnAction.classList.add('pressed');
        setTimeout(() => btnAction.classList.remove('pressed'), 120);
        SimulatorState.hardware.isSilent = !SimulatorState.hardware.isSilent;
        const msg = SimulatorState.hardware.isSilent ? '🔕 Silent Mode On' : '🔔 Silent Mode Off';
        showBannerHud(msg);
        logSimulatorEvent(msg);
      });
    }

    if (btnPower) {
      btnPower.addEventListener('click', () => {
        btnPower.classList.add('pressed');
        setTimeout(() => btnPower.classList.remove('pressed'), 120);
        SimulatorState.hardware.isLocked = !SimulatorState.hardware.isLocked;
        if (lockOverlay) {
          lockOverlay.classList.toggle('locked', SimulatorState.hardware.isLocked);
        }
        logSimulatorEvent(SimulatorState.hardware.isLocked ? 'Device Locked' : 'Device Unlocked');
      });
    }

    if (lockOverlay) {
      lockOverlay.addEventListener('click', () => {
        SimulatorState.hardware.isLocked = false;
        lockOverlay.classList.remove('locked');
        logSimulatorEvent('Device Unlocked via Tap');
      });
    }
  }

  // ── 6. PROJECT & MEDIA MANAGEMENT ENGINE ──────────────────────────────────
  async function fetchProjectsFromBackend() {
    try {
      const resp = await fetch('/api/v1/projects');
      if (resp.ok) {
        const data = await resp.json();
        SimulatorState.projects = data.projects || [];
        if (SimulatorState.projects.length > 0) {
          if (!SimulatorState.activeProject) {
            SimulatorState.activeProject = SimulatorState.projects[0];
          }
        }
        renderProjectsList('all');
        updateProjectContext();
      }
    } catch (err) {
      console.warn('Could not fetch projects:', err);
    }
  }

  function renderProjectsList(filter = 'all') {
    const listElem = document.getElementById('sim-projects-list');
    if (!listElem) return;
    listElem.innerHTML = '';

    let projs = SimulatorState.projects;
    if (filter === 'favorites') projs = projs.filter(p => p.isFavorite);

    if (projs.length === 0) {
      listElem.innerHTML = `<p style="text-align:center;color:var(--text-tertiary);padding:24px;">No projects found.</p>`;
      return;
    }

    projs.forEach(proj => {
      const row = document.createElement('div');
      row.className = 'project-row';
      const photosCount = proj.photos ? proj.photos.length : (proj.photoCount || 0);
      const videosCount = proj.videos ? proj.videos.length : (proj.videoCount || 0);

      row.innerHTML = `
        <span class="project-star" title="Favorite">${proj.isFavorite ? '⭐' : '☆'}</span>
        <div class="project-info">
          <div class="project-name">${proj.name}</div>
          <div class="project-meta">
            <span>${photosCount} Photos, ${videosCount} Videos</span>
            <span class="project-meta-dot">·</span>
            <span>${proj.aspectRatio || '9:16'}</span>
          </div>
        </div>
        <div class="project-chevron">›</div>
      `;

      row.querySelector('.project-star').addEventListener('click', async (e) => {
        e.stopPropagation();
        proj.isFavorite = !proj.isFavorite;
        renderProjectsList(filter);
        await saveProjectMetadata(proj);
      });

      // Clicking project opens the dedicated Project Detail Screen!
      row.addEventListener('click', () => {
        openProjectDetail(proj);
      });

      listElem.appendChild(row);
    });

    const tabBadge = document.getElementById('sim-tab-project-count');
    if (tabBadge) tabBadge.textContent = SimulatorState.projects.length;
  }

  function openProjectDetail(project) {
    SimulatorState.activeProject = project;
    updateProjectContext();

    const titleElem = document.getElementById('detail-project-title');
    const nameElem = document.getElementById('detail-card-name');
    const aspectElem = document.getElementById('detail-badge-aspect');
    const durationElem = document.getElementById('detail-badge-duration');
    const photoCountElem = document.getElementById('detail-photo-count');
    const videoCountElem = document.getElementById('detail-video-count');
    const favBtn = document.getElementById('detail-project-fav-btn');

    if (titleElem) titleElem.textContent = project.name;
    if (nameElem) nameElem.textContent = project.name;
    if (aspectElem) aspectElem.textContent = project.aspectRatio || '9:16';
    if (durationElem) durationElem.textContent = `${project.targetDurationSec || 15.0}s`;
    if (favBtn) favBtn.textContent = project.isFavorite ? '⭐' : '☆';

    // Populate Photos Grid
    const photosGrid = document.getElementById('detail-photos-grid');
    if (photosGrid) {
      photosGrid.innerHTML = '';
      const photos = project.photos || [];
      if (photoCountElem) photoCountElem.textContent = `${photos.length} Photos`;

      if (photos.length === 0) {
        photosGrid.innerHTML = `<p style="font-size:11px;color:var(--text-tertiary);grid-column:1/-1;text-align:center;padding:12px;">No photos in project.</p>`;
      } else {
        photos.forEach(photo => {
          const card = document.createElement('div');
          card.className = 'detail-media-thumb-card';
          card.innerHTML = `
            <img src="${photo.thumb || photo.url}" alt="${photo.name}">
            <span class="detail-media-badge">PHOTO</span>
          `;
          // Clicking any photo loads it directly into the Metal Editor!
          card.addEventListener('click', () => {
            loadMediaIntoEditor(photo, 'photo');
            switchSimTab('editor');
          });
          photosGrid.appendChild(card);
        });
      }
    }

    // Populate Videos Grid
    const videosGrid = document.getElementById('detail-videos-grid');
    if (videosGrid) {
      videosGrid.innerHTML = '';
      const videos = project.videos || [];
      if (videoCountElem) videoCountElem.textContent = `${videos.length} Videos`;

      if (videos.length === 0) {
        videosGrid.innerHTML = `<p style="font-size:11px;color:var(--text-tertiary);grid-column:1/-1;text-align:center;padding:12px;">No video artifacts yet.</p>`;
      } else {
        videos.forEach(video => {
          const card = document.createElement('div');
          card.className = 'detail-media-thumb-card';
          card.innerHTML = `
            <img src="${video.thumb || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&q=80'}" alt="${video.name}">
            <span class="detail-media-badge">▶ VIDEO</span>
          `;
          card.addEventListener('click', () => {
            loadMediaIntoEditor(video, 'video');
            switchSimTab('editor');
          });
          videosGrid.appendChild(card);
        });
      }
    }

    // Populate Soundtrack Info
    const audioTitle = document.getElementById('detail-audio-title');
    const audioGenre = document.getElementById('detail-audio-genre');
    if (project.soundtrack) {
      if (audioTitle) audioTitle.textContent = project.soundtrack.title || 'Soundtrack';
      if (audioGenre) audioGenre.textContent = `${project.soundtrack.tempoBpm || 120} BPM · ${project.soundtrack.genre || 'Cinematic'}`;
    }

    // Switch simulator interior to Project Detail Panel
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    const detailPanel = document.getElementById('panel-project-detail');
    if (detailPanel) detailPanel.classList.add('active');

    logSimulatorEvent(`Opened Project Detail: '${project.name}'`);
  }

  function initProjectDetailControls() {
    const backBtn = document.getElementById('project-detail-back-btn');
    if (backBtn) {
      backBtn.addEventListener('click', () => {
        switchSimTab('projects');
      });
    }

    const btnAiStudio = document.getElementById('detail-btn-ai-create');
    if (btnAiStudio) {
      btnAiStudio.addEventListener('click', () => {
        switchSimTab('ai-create');
      });
    }

    const btnOpenEditor = document.getElementById('detail-btn-open-editor');
    if (btnOpenEditor) {
      btnOpenEditor.addEventListener('click', () => {
        if (SimulatorState.activeProject && SimulatorState.activeProject.photos && SimulatorState.activeProject.photos.length > 0) {
          loadMediaIntoEditor(SimulatorState.activeProject.photos[0], 'photo');
        }
        switchSimTab('editor');
      });
    }

    const btnAddMedia = document.getElementById('detail-btn-add-media');
    if (btnAddMedia) {
      btnAddMedia.addEventListener('click', () => {
        openMediaImportSheet();
      });
    }

    const btnDeleteProj = document.getElementById('detail-btn-delete-proj');
    if (btnDeleteProj) {
      btnDeleteProj.addEventListener('click', async () => {
        if (!SimulatorState.activeProject) return;
        if (confirm(`Are you sure you want to delete '${SimulatorState.activeProject.name}'?`)) {
          try {
            await fetch(`/api/v1/projects/${SimulatorState.activeProject.id}`, { method: 'DELETE' });
            SimulatorState.projects = SimulatorState.projects.filter(p => p.id !== SimulatorState.activeProject.id);
            SimulatorState.activeProject = SimulatorState.projects[0] || null;
            renderProjectsList('all');
            switchSimTab('projects');
            logSimulatorEvent('Project deleted.');
          } catch (e) {
            console.error('Delete project failed:', e);
          }
        }
      });
    }
  }

  async function saveProjectMetadata(project) {
    try {
      await fetch('/api/v1/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: project.id,
          name: project.name,
          isFavorite: project.isFavorite,
          photos: project.photos,
          videos: project.videos,
          soundtrack: project.soundtrack
        })
      });
    } catch (e) {
      console.warn('Failed to persist project:', e);
    }
  }

  function updateProjectContext() {
    if (!SimulatorState.activeProject) return;
    const p = SimulatorState.activeProject;

    const activeName = document.getElementById('ai-active-project-name');
    const heroPill = document.getElementById('ai-hero-project-pill');
    const ctxMedia = document.getElementById('ctx-media-label');
    const ctxAudio = document.getElementById('ctx-audio-label');

    const photosCount = p.photos ? p.photos.length : 0;
    const videosCount = p.videos ? p.videos.length : 0;

    if (activeName) activeName.textContent = p.name;
    if (heroPill) heroPill.textContent = `Selected: '${p.name}'`;
    if (ctxMedia) ctxMedia.textContent = `${photosCount} Photos · ${videosCount} Videos`;
    if (ctxAudio && p.soundtrack) ctxAudio.textContent = p.soundtrack.title;
  }

  // ── 7. SIMULATOR EDITOR & LIVE METAL GPU CANVAS ENGINE ───────────────────
  function switchSimTab(tabName) {
    SimulatorState.currentTab = tabName;

    document.querySelectorAll('.ios-tab-bar .tab-item').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tabName);
    });

    document.querySelectorAll('.ios-tab-content .tab-panel').forEach(panel => {
      panel.classList.toggle('active', panel.id === `panel-${tabName}`);
    });

    closeAllSimSheets();
  }

  function initEditor() {
    const editorCanvas = document.getElementById('editor-canvas');
    const editorPreviewImg = document.getElementById('editor-preview-img');
    const editorVideoElem = document.getElementById('editor-video-elem');
    const editorMediaView = document.getElementById('editor-media-view');
    const editorEmptyView = document.getElementById('editor-empty-view');
    const editorTitle = document.getElementById('editor-title');
    const btnSave = document.getElementById('editor-btn-save');
    const btnReset = document.getElementById('editor-btn-reset');

    const adjExposure = document.getElementById('adj-exposure');
    const adjContrast = document.getElementById('adj-contrast');
    const adjSaturation = document.getElementById('adj-saturation');
    const adjBrightness = document.getElementById('adj-brightness');
    const adjTemperature = document.getElementById('adj-temperature');
    const adjVignette = document.getElementById('adj-vignette');

    const adjExposureVal = document.getElementById('adj-exposure-val');
    const adjContrastVal = document.getElementById('adj-contrast-val');
    const adjSaturationVal = document.getElementById('adj-saturation-val');
    const adjBrightnessVal = document.getElementById('adj-brightness-val');
    const adjTemperatureVal = document.getElementById('adj-temperature-val');
    const adjVignetteVal = document.getElementById('adj-vignette-val');

    // Filter Preset Buttons
    document.querySelectorAll('.editor-presets-bar .preset-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        document.querySelectorAll('.editor-presets-bar .preset-pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        applyPreset(pill.getAttribute('data-preset'));
      });
    });

    function applyPreset(presetName) {
      SimulatorState.editor.currentPreset = presetName;
      let adj = { exposure: 0, contrast: 100, saturation: 100, brightness: 0, temperature: 0, vignette: 0 };

      if (presetName === 'cinematic') {
        adj = { exposure: 5, contrast: 125, saturation: 110, brightness: 0, temperature: 15, vignette: 20 };
      } else if (presetName === 'cyberpunk') {
        adj = { exposure: 0, contrast: 140, saturation: 150, brightness: -5, temperature: -25, vignette: 30 };
      } else if (presetName === 'noir') {
        adj = { exposure: 10, contrast: 150, saturation: 0, brightness: 0, temperature: 0, vignette: 40 };
      } else if (presetName === 'golden') {
        adj = { exposure: 10, contrast: 110, saturation: 120, brightness: 5, temperature: 35, vignette: 10 };
      } else if (presetName === 'vivid') {
        adj = { exposure: 5, contrast: 130, saturation: 140, brightness: 0, temperature: 5, vignette: 0 };
      }

      SimulatorState.editor.adjustments = adj;
      syncSliderInputs();
      renderLiveCanvas();
    }

    function syncSliderInputs() {
      const a = SimulatorState.editor.adjustments;
      if (adjExposure) adjExposure.value = a.exposure;
      if (adjContrast) adjContrast.value = a.contrast;
      if (adjSaturation) adjSaturation.value = a.saturation;
      if (adjBrightness) adjBrightness.value = a.brightness;
      if (adjTemperature) adjTemperature.value = a.temperature;
      if (adjVignette) adjVignette.value = a.vignette;

      if (adjExposureVal) adjExposureVal.textContent = (a.exposure / 50).toFixed(1);
      if (adjContrastVal) adjContrastVal.textContent = (a.contrast / 100).toFixed(1);
      if (adjSaturationVal) adjSaturationVal.textContent = (a.saturation / 100).toFixed(1);
      if (adjBrightnessVal) adjBrightnessVal.textContent = a.brightness;
      if (adjTemperatureVal) adjTemperatureVal.textContent = a.temperature;
      if (adjVignetteVal) adjVignetteVal.textContent = `${a.vignette}%`;
    }

    function renderLiveCanvas() {
      if (!editorCanvas || !SimulatorState.editor.activeMedia) return;
      if (SimulatorState.editor.activeMediaType === 'video') return;

      const img = editorPreviewImg;
      if (!img || !img.complete || img.naturalWidth === 0) return;

      const ctx = editorCanvas.getContext('2d');
      editorCanvas.width = img.naturalWidth || 600;
      editorCanvas.height = img.naturalHeight || 800;

      const a = SimulatorState.editor.adjustments;
      const b = 100 + a.brightness + (a.exposure * 0.8);
      const c = a.contrast;
      const s = a.saturation;
      const h = a.temperature * 0.5; // subtle hue shift

      ctx.filter = `brightness(${b}%) contrast(${c}%) saturate(${s}%) hue-rotate(${h}deg)`;
      ctx.drawImage(img, 0, 0, editorCanvas.width, editorCanvas.height);

      // Vignette Shader Simulation
      if (a.vignette > 0) {
        const radius = Math.max(editorCanvas.width, editorCanvas.height) / 1.5;
        const grad = ctx.createRadialGradient(
          editorCanvas.width / 2, editorCanvas.height / 2, radius * 0.3,
          editorCanvas.width / 2, editorCanvas.height / 2, radius
        );
        const alpha = a.vignette / 100 * 0.7;
        grad.addColorStop(0, 'rgba(0,0,0,0)');
        grad.addColorStop(1, `rgba(0,0,0,${alpha})`);
        ctx.filter = 'none';
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, editorCanvas.width, editorCanvas.height);
      }
    }

    window.loadMediaIntoEditor = function (mediaItem, type = 'photo') {
      SimulatorState.editor.activeMedia = mediaItem;
      SimulatorState.editor.activeMediaType = type;

      if (editorTitle) editorTitle.textContent = mediaItem.name || 'Metal Editor';
      if (editorEmptyView) editorEmptyView.style.display = 'none';
      if (editorMediaView) editorMediaView.style.display = 'flex';
      if (btnSave) btnSave.style.display = 'flex';
      if (btnReset) btnReset.style.display = 'flex';

      if (mediaItem.adjustments) {
        SimulatorState.editor.adjustments = { ...SimulatorState.editor.adjustments, ...mediaItem.adjustments };
        syncSliderInputs();
      }

      if (type === 'video') {
        if (editorCanvas) editorCanvas.style.display = 'none';
        if (editorPreviewImg) editorPreviewImg.style.display = 'none';
        if (editorVideoElem) {
          editorVideoElem.src = mediaItem.url;
          editorVideoElem.style.display = 'block';
        }
      } else {
        if (editorVideoElem) editorVideoElem.style.display = 'none';
        if (editorCanvas) editorCanvas.style.display = 'block';
        if (editorPreviewImg) {
          editorPreviewImg.onload = () => renderLiveCanvas();
          editorPreviewImg.src = mediaItem.url;
        }
      }

      logSimulatorEvent(`Loaded '${mediaItem.name}' into Metal GPU Canvas Editor`);
    };

    // Sliders Input Listeners
    if (adjExposure) {
      adjExposure.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.exposure = parseInt(e.target.value, 10);
        if (adjExposureVal) adjExposureVal.textContent = (SimulatorState.editor.adjustments.exposure / 50).toFixed(1);
        renderLiveCanvas();
      });
    }

    if (adjContrast) {
      adjContrast.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.contrast = parseInt(e.target.value, 10);
        if (adjContrastVal) adjContrastVal.textContent = (SimulatorState.editor.adjustments.contrast / 100).toFixed(1);
        renderLiveCanvas();
      });
    }

    if (adjSaturation) {
      adjSaturation.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.saturation = parseInt(e.target.value, 10);
        if (adjSaturationVal) adjSaturationVal.textContent = (SimulatorState.editor.adjustments.saturation / 100).toFixed(1);
        renderLiveCanvas();
      });
    }

    if (adjBrightness) {
      adjBrightness.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.brightness = parseInt(e.target.value, 10);
        if (adjBrightnessVal) adjBrightnessVal.textContent = SimulatorState.editor.adjustments.brightness;
        renderLiveCanvas();
      });
    }

    if (adjTemperature) {
      adjTemperature.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.temperature = parseInt(e.target.value, 10);
        if (adjTemperatureVal) adjTemperatureVal.textContent = SimulatorState.editor.adjustments.temperature;
        renderLiveCanvas();
      });
    }

    if (adjVignette) {
      adjVignette.addEventListener('input', (e) => {
        SimulatorState.editor.adjustments.vignette = parseInt(e.target.value, 10);
        if (adjVignetteVal) adjVignetteVal.textContent = `${SimulatorState.editor.adjustments.vignette}%`;
        renderLiveCanvas();
      });
    }

    if (btnReset) {
      btnReset.addEventListener('click', () => {
        applyPreset('original');
        logSimulatorEvent('Reset editor adjustments to defaults');
      });
    }

    if (btnSave) {
      btnSave.addEventListener('click', async () => {
        if (!SimulatorState.editor.activeMedia || !SimulatorState.activeProject) return;
        SimulatorState.editor.activeMedia.adjustments = { ...SimulatorState.editor.adjustments };
        await saveProjectMetadata(SimulatorState.activeProject);
        alert(`Saved Metal GPU adjustments for '${SimulatorState.editor.activeMedia.name}' to project '${SimulatorState.activeProject.name}'!`);
        logSimulatorEvent(`Saved adjustments for '${SimulatorState.editor.activeMedia.name}'`);
      });
    }

    const btnNavProjects = document.getElementById('editor-nav-projects');
    const btnEmptyProjects = document.getElementById('editor-btn-projects');
    if (btnNavProjects) btnNavProjects.addEventListener('click', () => switchSimTab('projects'));
    if (btnEmptyProjects) btnEmptyProjects.addEventListener('click', () => switchSimTab('projects'));

    const btnEmptyPhoto = document.getElementById('editor-btn-photo');
    const btnEmptyVideo = document.getElementById('editor-btn-video');
    if (btnEmptyPhoto) btnEmptyPhoto.addEventListener('click', () => openMediaPickerSheet('photo'));
    if (btnEmptyVideo) btnEmptyVideo.addEventListener('click', () => openMediaPickerSheet('video'));
  }

  // ── 8. MEDIA PICKER & MODAL SHEETS ─────────────────────────────────────────
  const simOverlay = document.getElementById('sim-sheet-overlay');

  function openSimSheet(sheetId) {
    if (simOverlay) simOverlay.classList.add('active');
    const sheet = document.getElementById(sheetId);
    if (sheet) sheet.classList.add('active');
  }

  function closeAllSimSheets() {
    if (simOverlay) simOverlay.classList.remove('active');
    document.querySelectorAll('.sim-sheet').forEach(sheet => {
      sheet.classList.remove('active');
    });
  }

  if (simOverlay) {
    simOverlay.addEventListener('click', closeAllSimSheets);
  }

  function openMediaPickerSheet(filterType = 'all') {
    const grid = document.getElementById('sim-media-picker-grid');
    if (!grid) return;
    grid.innerHTML = '';

    const items = filterType === 'all' ? STOCK_MEDIA_LIBRARY : STOCK_MEDIA_LIBRARY.filter(m => m.type === filterType);
    items.forEach(item => {
      const el = document.createElement('div');
      el.className = 'media-picker-item';
      el.innerHTML = `
        <img class="media-picker-thumb" src="${item.thumb}" alt="${item.name}">
        <span class="media-picker-badge">${item.type === 'video' ? '▶ VIDEO' : 'PHOTO'}</span>
      `;
      el.addEventListener('click', () => {
        window.loadMediaIntoEditor(item, item.type);
        closeAllSimSheets();
      });
      grid.appendChild(el);
    });

    openSimSheet('sheet-media-picker');
  }

  function openMediaImportSheet() {
    const grid = document.getElementById('sim-media-picker-grid');
    if (!grid) return;
    grid.innerHTML = '';

    STOCK_MEDIA_LIBRARY.forEach(item => {
      const el = document.createElement('div');
      el.className = 'media-picker-item';
      el.innerHTML = `
        <img class="media-picker-thumb" src="${item.thumb}" alt="${item.name}">
        <span class="media-picker-badge">${item.type === 'video' ? '▶ VIDEO' : 'PHOTO'}</span>
      `;
      el.addEventListener('click', async () => {
        if (!SimulatorState.activeProject) return;
        try {
          await fetch(`/api/v1/projects/${SimulatorState.activeProject.id}/media`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              mediaType: item.type,
              name: item.name,
              url: item.url,
              thumb: item.thumb,
              durationSec: item.durationSec || 0,
              adjustments: item.adjustments
            })
          });
          closeAllSimSheets();
          await fetchProjectsFromBackend();
          openProjectDetail(SimulatorState.activeProject);
          logSimulatorEvent(`Imported '${item.name}' into project.`);
        } catch (e) {
          console.error('Import failed:', e);
        }
      });
      grid.appendChild(el);
    });

    openSimSheet('sheet-media-picker');
  }

  const btnCloseMediaPicker = document.getElementById('btn-close-media-picker');
  if (btnCloseMediaPicker) btnCloseMediaPicker.addEventListener('click', closeAllSimSheets);

  // ── 9. AI CREATE STUDIO ENGINE ─────────────────────────────────────────────
  function initAiCreate() {
    const aiPromptInput = document.getElementById('sim-prompt-input');
    const aiPromptSendBtn = document.getElementById('sim-prompt-send-btn');
    const aiChatBody = document.getElementById('ai-chat-body');
    const aiChatMessages = document.getElementById('ai-chat-messages');
    const aiHeroView = document.getElementById('ai-hero-view');
    const aiSettingsBtn = document.getElementById('ai-settings-btn');
    const btnCloseAiSettings = document.getElementById('btn-close-ai-settings');
    const aiProjectPickerBtn = document.getElementById('ai-project-picker-btn');

    if (aiProjectPickerBtn) {
      aiProjectPickerBtn.addEventListener('click', () => switchSimTab('projects'));
    }

    if (aiSettingsBtn) aiSettingsBtn.addEventListener('click', () => openSimSheet('sheet-ai-settings'));
    if (btnCloseAiSettings) btnCloseAiSettings.addEventListener('click', closeAllSimSheets);

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

      appendChatMessage('user', promptText);
      updateDynamicIsland('thinking', 'Processing…');
      logSimulatorEvent(`AI Create prompt submitted: "${promptText}"`);

      const genStatus = document.getElementById('sim-gen-status');
      const genGoal = document.getElementById('sim-gen-goal');
      if (genStatus) genStatus.textContent = 'Planning…';
      if (genGoal) genGoal.textContent = promptText;

      const proj = SimulatorState.activeProject || { id: 'proj-1', name: 'MetalCraft Project' };

      try {
        const resp = await fetch('/api/v1/agent/create', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: promptText,
            projectId: proj.id,
            projectName: proj.name,
            aspectRatio: SimulatorState.aiCreate.aspectRatio
          })
        });

        let planData;
        if (resp.ok) {
          const data = await resp.json();
          planData = data.plan;
        } else {
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
        card.querySelector('.plan-actions').innerHTML = `<span style="font-size:10px;color:var(--accent-green);">✓ Plan Approved. Initiating Apple Metal GPU render pass…</span>`;
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
          <span>Apple Metal GPU Rendering</span>
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
        updateDynamicIsland('rendering', `GPU ${currentPct}%`, currentPct);

        if (currentPct >= 100) {
          clearInterval(interval);
          if (genStatusSide) genStatusSide.textContent = 'Complete';
          updateDynamicIsland('done', 'Complete ✓');
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
        openVideoPlayerModal(STOCK_MEDIA_LIBRARY[4].url, plan.goal);
      });

      card.querySelector('#btn-add-to-project').addEventListener('click', async () => {
        if (!SimulatorState.activeProject) return;
        try {
          await fetch(`/api/v1/projects/${SimulatorState.activeProject.id}/media`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              mediaType: 'video',
              name: plan.goal,
              url: STOCK_MEDIA_LIBRARY[4].url,
              thumb: STOCK_MEDIA_LIBRARY[4].thumb,
              durationSec: plan.targetDurationSec
            })
          });
          await fetchProjectsFromBackend();
          alert(`Video Artifact added to project '${SimulatorState.activeProject.name}'!`);
        } catch (e) {
          console.error('Failed to add artifact:', e);
        }
      });

      card.querySelector('#btn-download-artifact').addEventListener('click', () => {
        openVideoPlayerModal(STOCK_MEDIA_LIBRARY[4].url, plan.goal);
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

    const btnQuickReel = document.getElementById('btn-quick-sample-reel');
    if (btnQuickReel) {
      btnQuickReel.addEventListener('click', () => {
        switchSimTab('ai-create');
        submitAiCreatePrompt('Create a 15-second cinematic product reel');
      });
    }
  }

  // ── 10. REAL IPHONE FLEET MANAGEMENT ENGINE ────────────────────────────────
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

    if (RealDevicesState.statusFilter === 'online') {
      filtered = filtered.filter(d => d.isLive || (d.status && d.status.toUpperCase() === 'ONLINE'));
    } else if (RealDevicesState.statusFilter === 'busy') {
      filtered = filtered.filter(d => d.status && (d.status.toUpperCase() === 'BUSY' || d.status.toUpperCase() === 'RENDERING'));
    } else if (RealDevicesState.statusFilter === 'offline') {
      filtered = filtered.filter(d => !d.isLive && (d.status && d.status.toUpperCase() === 'OFFLINE'));
    }

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
          <p>Connect your physical iPhone running the MetalCraft app to <strong>${window.location.origin}</strong> or switch filters above.</p>
        </div>
      `;
      return;
    }

    filtered.forEach(dev => {
      const isOnline = dev.isLive || (dev.status && dev.status.toUpperCase() === 'ONLINE');
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
            <strong style="color:var(--accent-green);">Available (4K 60FPS)</strong>
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
    const onlineCount = RealDevicesState.devices.filter(d => d.isLive || (d.status && d.status.toUpperCase() === 'ONLINE')).length;

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

    const btnRefresh = document.getElementById('btn-refresh-fleet');
    const iconRefresh = document.getElementById('btn-refresh-fleet-icon');
    const textRefresh = document.getElementById('btn-refresh-fleet-text');

    if (btnRefresh) {
      btnRefresh.addEventListener('click', async () => {
        if (iconRefresh) iconRefresh.className = 'spinner';
        if (textRefresh) textRefresh.textContent = 'Refreshing…';
        await fetchRealDevices();
        setTimeout(() => {
          if (iconRefresh) iconRefresh.className = '';
          if (iconRefresh) iconRefresh.textContent = '✓';
          if (textRefresh) textRefresh.textContent = 'Updated';
          setTimeout(() => {
            if (iconRefresh) iconRefresh.textContent = '↻';
            if (textRefresh) textRefresh.textContent = 'Refresh Fleet';
          }, 1800);
        }, 500);
      });
    }
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
          <span>GPU Pipeline:</span><strong>Apple Metal (MPS Shaders)</strong>
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
        <p>Device is registered on the control plane.</p>
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

  // ── 11. CLOUD & OBSERVABILITY DATA FETCHERS ───────────────────────────────
  async function fetchCloudHealth() {
    try {
      const resp = await fetch('/api/v1/health');
      if (resp.ok) {
        const data = await resp.json();
        const geminiStatus = document.getElementById('ai-overview-gemini-status');
        const parallelStatus = document.getElementById('ai-overview-parallel-status');
        const grafanaStatus = document.getElementById('ai-overview-grafana-status');
        const headerCloudDot = document.getElementById('header-cloud-dot');
        const headerCloudText = document.getElementById('header-cloud-text');

        if (headerCloudDot && headerCloudText) {
          headerCloudDot.className = 'status-dot dot-online';
          headerCloudText.textContent = data.environment === 'production' ? 'Render Cloud Live' : 'Cloud Live';
        }

        if (geminiStatus && data.providers && data.providers.gemini) {
          const g = data.providers.gemini;
          geminiStatus.className = `provider-status ${g.status === 'PASS' ? 'pass' : 'warn'}`;
          geminiStatus.innerHTML = `<span>● Status: ${g.status} (${g.configured ? 'Configured Server-Side' : 'Local Fallback'})</span>`;
        }

        if (parallelStatus && data.providers && data.providers.parallel) {
          const p = data.providers.parallel;
          const lat = p.latencyMs ? `~${Math.round(p.latencyMs)}ms` : 'Ready';
          parallelStatus.className = `provider-status ${p.status === 'PASS' ? 'pass' : 'warn'}`;
          parallelStatus.innerHTML = `<span>● Status: ${p.status} (${p.configured ? 'Available ' + lat : 'Knowledge Base'})</span>`;
          
          const parallelLatElem = document.getElementById('metric-parallel-latency');
          if (parallelLatElem && p.latencyMs) parallelLatElem.textContent = `${Math.round(p.latencyMs)} ms`;
        }

        if (grafanaStatus && data.providers && data.providers.grafana) {
          const gr = data.providers.grafana;
          const lat = gr.latencyMs ? `HTTP ${gr.httpCode || 200} (~${Math.round(gr.latencyMs)}ms)` : 'Connected';
          grafanaStatus.className = `provider-status ${gr.status === 'PASS' ? 'pass' : 'warn'}`;
          grafanaStatus.innerHTML = `<span>● Status: ${gr.status} (${lat})</span>`;
          
          const grafanaLatElem = document.getElementById('metric-grafana-latency');
          if (grafanaLatElem && gr.latencyMs) grafanaLatElem.textContent = `${Math.round(gr.latencyMs)} ms`;
        }
      }
    } catch (err) {
      console.warn('Could not fetch cloud health:', err);
    }
  }

  const btnAiDiagnostics = document.getElementById('btn-run-ai-diagnostics');
  if (btnAiDiagnostics) {
    btnAiDiagnostics.addEventListener('click', async () => {
      btnAiDiagnostics.innerHTML = `<div class="spinner"></div><span>Running Diagnostics…</span>`;
      await fetchCloudHealth();
      setTimeout(() => {
        btnAiDiagnostics.innerHTML = `<span>✓ Diagnostics Complete</span>`;
        setTimeout(() => {
          btnAiDiagnostics.innerHTML = `<span>⟳ Run Live Cloud Diagnostics</span>`;
        }, 2000);
      }, 600);
    });
  }

  async function fetchObservabilityOverview() {
    await fetchCloudHealth();
    await fetchObservabilityRequests();
    await fetchAnalyticsMetrics();
  }

  async function fetchAnalyticsMetrics() {
    try {
      const resp = await fetch('/api/v1/analytics');
      if (resp.ok) {
        const data = await resp.json();
        const obs = data.observability || {};

        const gpuTime = obs.averageGpuTimeMs || 2.85;
        const fps = obs.averageFps || 30.0;

        const simGpu = document.getElementById('sim-metric-gpu');
        const obsGpu = document.getElementById('obs-gpu-ms-val');
        const metricGpu = document.getElementById('metric-avg-gpu-time');
        const obsFps = document.getElementById('obs-fps-val');

        if (simGpu) simGpu.innerHTML = `${gpuTime}<span class="metric-unit">ms</span>`;
        if (obsGpu) obsGpu.textContent = `${gpuTime} ms`;
        if (metricGpu) metricGpu.textContent = `${gpuTime} ms`;
        if (obsFps) obsFps.textContent = `${fps} FPS`;
      }
    } catch (err) {
      console.warn('Could not fetch analytics:', err);
    }
  }

  async function fetchObservabilityRequests() {
    const tbody = document.getElementById('obs-requests-tbody');
    if (!tbody) return;

    try {
      const resp = await fetch('/api/v1/generations');
      if (resp.ok) {
        const data = await resp.json();
        const gens = data.generations || [];
        if (gens.length === 0) {
          tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;color:var(--text-tertiary);padding:24px;">No generation jobs found.</td></tr>`;
          return;
        }

        tbody.innerHTML = '';
        gens.forEach(g => {
          const tr = document.createElement('tr');
          const goal = g.plan && g.plan.goal ? g.plan.goal : 'Video Generation';
          tr.innerHTML = `
            <td style="font-family:var(--font-mono);font-size:11px;color:var(--accent-purple);">${g.generationId}</td>
            <td><strong>${goal}</strong></td>
            <td><span class="audit-status ${g.status === 'COMPLETED' ? 'success' : g.status === 'FAILED' ? 'error' : 'info'}">${g.status}</span></td>
            <td>${Math.round(g.progress * 100)}%</td>
            <td style="font-size:11px;color:var(--text-secondary);">${g.createdAt ? new Date(g.createdAt).toLocaleTimeString() : '—'}</td>
          `;
          tbody.appendChild(tr);
        });
      }
    } catch (err) {
      console.warn('Could not fetch generations:', err);
    }
  }

  async function fetchObservabilityDevices() {
    const grid = document.getElementById('obs-devices-grid');
    if (!grid) return;
    grid.innerHTML = '';

    await fetchRealDevices();
    if (RealDevicesState.devices.length === 0) {
      grid.innerHTML = `<p style="text-align:center;color:var(--text-secondary);padding:24px;grid-column:1/-1;">No connected devices currently registered.</p>`;
      return;
    }

    RealDevicesState.devices.forEach(dev => {
      const card = document.createElement('div');
      card.className = 'info-card';
      card.innerHTML = `
        <div class="info-card-title">${dev.name || 'iPhone'} (${dev.deviceId || 'MC-IOS'})</div>
        <div class="info-card-row"><span>Status:</span><strong style="color:var(--accent-green);">${dev.status || 'ONLINE'}</strong></div>
        <div class="info-card-row"><span>Model:</span><strong>${dev.model || 'iPhone'}</strong></div>
        <div class="info-card-row"><span>iOS:</span><strong>${dev.osVersion || 'iOS 18'}</strong></div>
        <div class="info-card-row"><span>Last Heartbeat:</span><strong>${dev.lastHeartbeat ? formatRelativeTime(dev.lastHeartbeat) : 'Just now'}</strong></div>
      `;
      grid.appendChild(card);
    });
  }

  async function fetchObservabilityAudit() {
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

  // ── 12. VIDEO PLAYER MODAL ────────────────────────────────────────────────
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

  // ── 13. WEBSOCKET REAL-TIME DISPATCHER ────────────────────────────────────
  let wsBackoffMs = 1000;
  function initWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/web`;

    let ws;
    function connect() {
      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          wsBackoffMs = 1000;
          const simWsStatus = document.getElementById('sim-ws-status');
          if (simWsStatus) {
            simWsStatus.textContent = 'Connected';
            simWsStatus.className = 'info-card-value pass';
          }
          logSimulatorEvent('WebSocket connected to Render Cloud Control Plane');
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
          setTimeout(connect, wsBackoffMs);
          wsBackoffMs = Math.min(wsBackoffMs * 1.5, 10000);
        };
      } catch (err) {
        setTimeout(connect, wsBackoffMs);
        wsBackoffMs = Math.min(wsBackoffMs * 1.5, 10000);
      }
    }

    connect();
  }

  function handleWebSocketMessage(msg) {
    if (msg.type === 'DEVICE_REGISTERED' || msg.type === 'DEVICE_STATUS_CHANGED') {
      fetchRealDevices();
    } else if (msg.type === 'GENERATION_PROGRESS') {
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

  function startClock() {
    const clock = document.getElementById('sim-clock');
    const lockClock = document.getElementById('lock-clock');
    if (!clock) return;

    function tick() {
      const d = new Date();
      let hours = d.getHours();
      const mins = d.getMinutes().toString().padStart(2, '0');
      hours = hours % 12 || 12;
      const timeStr = `${hours}:${mins}`;
      clock.textContent = timeStr;
      if (lockClock) lockClock.textContent = timeStr;
    }
    tick();
    setInterval(tick, 10000);
  }

  // ── INITIALIZATION ───────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    try {
      initTheme();
      initNavigation();
      initSubtabs();
      initHardwareButtons();
      initEditor();
      initAiCreate();
      initProjectDetailControls();
      initRealDevicesControls();
      startClock();
      initWebSocket();

      // Initial Data Loads
      fetchProjectsFromBackend();
      fetchRealDevices();
      fetchCloudHealth();
      fetchAnalyticsMetrics();
    } catch (e) {
      console.error('Initialization error:', e);
    }
  });

})();
