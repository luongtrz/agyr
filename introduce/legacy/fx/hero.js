/**
 * fx/hero.js — agyr Hero Section & Navbar "Wow Factor" Engine
 * 
 * Features:
 * - Constellation canvas with simulated 5-slot Google Account network & 429 auto-rotation hops
 * - Live failover simulation ticker badge with smooth text cycling
 * - Floating stat chips with gentle cursor repulsion & parallax
 * - Terminal cursor & glowing backdrops
 * - Navbar glass blur enhancements, scroll reading progress bar & smooth sliding indicator
 * - Automatic pause off-screen (IntersectionObserver) & tab hidden (visibilitychange)
 * - Full prefers-reduced-motion & mobile graceful degradation
 */

(function initAgyrHero() {
  'use strict';

  // Prevent multiple executions if loaded more than once
  if (window.__AGYR_HERO_INITIALIZED__) return;
  window.__AGYR_HERO_INITIALIZED__ = true;

  const prefersReducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Run when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }

  function setup() {
    try {
      const heroSection = document.querySelector('.hero-section');
      if (!heroSection) return;

      injectHeroElements(heroSection);
      injectNavbarEnhancements();
      initHeroCanvas(heroSection);
      initHeroTicker(heroSection);
      initNavbarIndicator();
    } catch (err) {
      // Fail silently to never break the base landing page
      console.warn('agyr hero FX initialization encountered a minor issue:', err);
    }
  }

  /* ==========================================================================
     1. DOM Injection
     ========================================================================== */

  function injectHeroElements(heroSection) {
    // 1. Hero Backdrop (Aurora & Canvas)
    const backdrop = document.createElement('div');
    backdrop.className = 'hero-backdrop';
    backdrop.setAttribute('aria-hidden', 'true');
    backdrop.innerHTML = `
      <div class="hero-aurora-blob hero-aurora-1"></div>
      <div class="hero-aurora-blob hero-aurora-2"></div>
      <div class="hero-aurora-blob hero-aurora-3"></div>
      <div class="hero-grid-perspective"></div>
      <canvas class="hero-canvas" id="heroCanvas"></canvas>
    `;
    heroSection.prepend(backdrop);

    // 2. Live Simulation Ticker Badge (Enhancement above the Headline)
    const heroTitle = heroSection.querySelector('.hero-title');
    if (heroTitle && heroTitle.parentNode) {
      const ticker = document.createElement('div');
      ticker.className = 'hero-ticker-badge';
      ticker.setAttribute('aria-label', 'agyr auto-failover simulation');
      ticker.innerHTML = `
        <span class="ticker-pulse" aria-hidden="true"></span>
        <span class="ticker-tag">Live Engine</span>
        <span class="ticker-text" id="heroTickerText">Slot #1 hit HTTP 429 ➔ Auto-swapped to Slot #2 in 0.84s</span>
      `;
      heroTitle.parentNode.insertBefore(ticker, heroTitle);
    }

    // 3. Floating Frosted Stat Chips
    const chipsLayer = document.createElement('div');
    chipsLayer.className = 'hero-chips-layer';
    chipsLayer.setAttribute('aria-hidden', 'true');
    chipsLayer.innerHTML = `
      <div class="hero-chip chip-1" title="Real-time 429 detection & automatic account rotation">
        <div class="chip-icon">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="23 4 23 10 17 10"></polyline>
            <polyline points="1 20 1 14 7 14"></polyline>
            <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path>
          </svg>
        </div>
        <div class="chip-content">
          <div class="chip-title">429 Auto-Failover</div>
          <div class="chip-sub">&lt; 1s slot switch · no restart</div>
        </div>
        <span class="chip-badge chip-badge-emerald">Active</span>
      </div>

      <div class="hero-chip chip-2" title="100% Genuine Google CLI TLS stack">
        <div class="chip-icon">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
          </svg>
        </div>
        <div class="chip-content">
          <div class="chip-title">Zero Ban Risk</div>
          <div class="chip-sub">Official TLS fingerprints</div>
        </div>
        <span class="chip-badge chip-badge-cyan">100% Local</span>
      </div>

      <div class="hero-chip chip-3" title="Pure Bash script with zero background memory">
        <div class="chip-icon">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <rect x="2" y="2" width="20" height="8" rx="2" ry="2"></rect>
            <rect x="2" y="14" width="20" height="8" rx="2" ry="2"></rect>
            <line x1="6" y1="6" x2="6.01" y2="6"></line>
            <line x1="6" y1="18" x2="6.01" y2="18"></line>
          </svg>
        </div>
        <div class="chip-content">
          <div class="chip-title">0 MB Background RAM</div>
          <div class="chip-sub">Pure Bash · zero daemons</div>
        </div>
        <span class="chip-badge chip-badge-purple">Ultra-light</span>
      </div>
    `;
    heroSection.appendChild(chipsLayer);

    // 4. Terminal Ambient Glow & Blinking Cursor
    const terminal = heroSection.querySelector('.install-terminal');
    if (terminal && terminal.parentNode) {
      const glow = document.createElement('div');
      glow.className = 'install-terminal-glow';
      glow.setAttribute('aria-hidden', 'true');
      terminal.parentNode.insertBefore(glow, terminal);
    }

    const cmdBox = heroSection.querySelector('#installCmdText');
    if (cmdBox && !cmdBox.querySelector('.cmd-cursor')) {
      const cursor = document.createElement('span');
      cursor.className = 'cmd-cursor';
      cursor.setAttribute('aria-hidden', 'true');
      cmdBox.appendChild(cursor);
    }
  }

  function injectNavbarEnhancements() {
    const navbar = document.querySelector('.navbar');
    if (!navbar) return;

    // Scroll reading progress bar
    if (!document.getElementById('navScrollProgress')) {
      const progressBar = document.createElement('div');
      progressBar.id = 'navScrollProgress';
      progressBar.className = 'nav-scroll-progress';
      progressBar.setAttribute('aria-hidden', 'true');
      navbar.appendChild(progressBar);

      const updateScrollProgress = () => {
        const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
        const progress = totalHeight > 0 ? (window.scrollY / totalHeight) * 100 : 0;
        progressBar.style.width = Math.min(100, Math.max(0, progress)) + '%';
      };

      window.addEventListener('scroll', updateScrollProgress, { passive: true });
      updateScrollProgress();
    }

    // Sliding indicator in nav links
    const navLinks = navbar.querySelector('.nav-links');
    if (navLinks && !document.getElementById('navIndicator')) {
      const indicator = document.createElement('div');
      indicator.id = 'navIndicator';
      indicator.className = 'nav-indicator';
      indicator.setAttribute('aria-hidden', 'true');
      navLinks.appendChild(indicator);
    }
  }

  /* ==========================================================================
     2. Constellation & Account Node Canvas Engine
     ========================================================================== */

  function initHeroCanvas(heroSection) {
    const canvas = document.getElementById('heroCanvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = 0;
    let height = 0;
    let dpr = 1;
    let isVisible = true;
    let animId = null;

    // Account Nodes representing Google Account Slots (1 to 5)
    // plus secondary constellation star particles
    let accountNodes = [];
    let backgroundParticles = [];
    let packets = [];
    let activeSlotIndex = 0;
    let lastFailoverTime = Date.now();
    let shockwaves = [];

    // Mouse coordinates for gentle interactive repulsion
    const mouse = { x: -1000, y: -1000, targetX: -1000, targetY: -1000 };

    heroSection.addEventListener('mousemove', (e) => {
      const rect = heroSection.getBoundingClientRect();
      mouse.targetX = e.clientX - rect.left;
      mouse.targetY = e.clientY - rect.top;
    }, { passive: true });

    heroSection.addEventListener('mouseleave', () => {
      mouse.targetX = -1000;
      mouse.targetY = -1000;
    }, { passive: true });

    function resize() {
      const rect = heroSection.getBoundingClientRect();
      width = Math.max(300, rect.width);
      height = Math.max(300, rect.height);
      dpr = Math.min(window.devicePixelRatio || 1, 2);

      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = width + 'px';
      canvas.style.height = height + 'px';

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      initNodes();

      if (prefersReducedMotion) {
        drawStaticFrame();
      }
    }

    function initNodes() {
      accountNodes = [];
      backgroundParticles = [];
      packets = [];
      shockwaves = [];

      // Create 5 primary Account Slot Hubs positioned in a natural arc
      const slotConfigs = [
        { label: 'Slot #1', status: 'active', color: '#22c55e', rx: 0.18, ry: 0.28 },
        { label: 'Slot #2', status: 'ready',  color: '#38bdf8', rx: 0.36, ry: 0.16 },
        { label: 'Slot #3', status: 'ready',  color: '#38bdf8', rx: 0.64, ry: 0.16 },
        { label: 'Slot #4', status: 'cooldown', color: '#f59e0b', rx: 0.82, ry: 0.28 },
        { label: 'Slot #5', status: 'ready',  color: '#c084fc', rx: 0.50, ry: 0.38 }
      ];

      accountNodes = slotConfigs.map((cfg, idx) => ({
        id: idx,
        label: cfg.label,
        status: cfg.status,
        color: cfg.color,
        baseX: width * cfg.rx,
        baseY: height * cfg.ry,
        x: width * cfg.rx,
        y: height * cfg.ry,
        radius: idx === activeSlotIndex ? 10 : 7,
        pulse: 0,
        pulseSpeed: 0.04 + idx * 0.01,
        vx: (Math.random() - 0.5) * 0.25,
        vy: (Math.random() - 0.5) * 0.25,
        isSlot: true
      }));

      // Background ambient star particles (22 particles)
      const particleCount = width < 600 ? 12 : 24;
      for (let i = 0; i < particleCount; i++) {
        backgroundParticles.push({
          x: Math.random() * width,
          y: Math.random() * height,
          baseX: Math.random() * width,
          baseY: Math.random() * height,
          radius: Math.random() * 1.8 + 0.8,
          vx: (Math.random() - 0.5) * 0.35,
          vy: (Math.random() - 0.5) * 0.35,
          alpha: Math.random() * 0.4 + 0.15,
          isSlot: false
        });
      }
    }

    // Trigger an account rotation event: Active slot gets 429, emits packet to next ready slot
    function triggerAccountFailover() {
      if (accountNodes.length < 2) return;

      const fromNode = accountNodes[activeSlotIndex];
      // Pick next slot
      const nextIndex = (activeSlotIndex + 1) % accountNodes.length;
      const toNode = accountNodes[nextIndex];

      // Mark fromNode as cooldown (amber)
      fromNode.status = 'cooldown';
      fromNode.color = '#f59e0b';

      // Shockwave burst at fromNode
      shockwaves.push({
        x: fromNode.x,
        y: fromNode.y,
        radius: fromNode.radius,
        maxRadius: 45,
        color: 'rgba(239, 68, 68, 0.7)',
        alpha: 0.8
      });

      // Send bright rotation packet
      packets.push({
        from: fromNode,
        to: toNode,
        progress: 0,
        speed: 0.024,
        size: 4,
        color: '#22c55e',
        trail: [],
        onComplete: () => {
          // toNode becomes active
          toNode.status = 'active';
          toNode.color = '#22c55e';
          activeSlotIndex = nextIndex;

          // Arrival shockwave
          shockwaves.push({
            x: toNode.x,
            y: toNode.y,
            radius: toNode.radius,
            maxRadius: 55,
            color: 'rgba(34, 197, 94, 0.8)',
            alpha: 1
          });

          // Restore other slots to ready over time
          accountNodes.forEach((node, i) => {
            if (i !== activeSlotIndex) {
              if (node.status === 'cooldown' && i !== fromNode.id) {
                node.status = 'ready';
                node.color = '#38bdf8';
              }
            }
          });
        }
      });
    }

    // Static frame for reduced motion users
    function drawStaticFrame() {
      ctx.clearRect(0, 0, width, height);

      // Draw faint connections
      for (let i = 0; i < accountNodes.length; i++) {
        for (let j = i + 1; j < accountNodes.length; j++) {
          const a = accountNodes[i];
          const b = accountNodes[j];
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = 'rgba(56, 189, 248, 0.12)';
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }

      // Draw nodes
      accountNodes.forEach(node => {
        ctx.beginPath();
        ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
        ctx.fillStyle = node.color;
        ctx.fill();

        // Node label
        ctx.font = '10px ui-monospace, monospace';
        ctx.fillStyle = 'rgba(226, 232, 240, 0.65)';
        ctx.textAlign = 'center';
        ctx.fillText(node.label, node.x, node.y + node.radius + 14);
      });
    }

    // Main animation loop
    function animate() {
      if (!isVisible) return;

      ctx.clearRect(0, 0, width, height);

      // Smooth mouse lerping
      mouse.x += (mouse.targetX - mouse.x) * 0.08;
      mouse.y += (mouse.targetY - mouse.y) * 0.08;

      const now = Date.now();

      // Trigger failover cycle every 4.2 seconds
      if (now - lastFailoverTime > 4200) {
        triggerAccountFailover();
        lastFailoverTime = now;
      }

      // Update & draw background particles
      backgroundParticles.forEach(p => {
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0) p.x = width;
        if (p.x > width) p.x = 0;
        if (p.y < 0) p.y = height;
        if (p.y > height) p.y = 0;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(148, 163, 184, ${p.alpha})`;
        ctx.fill();
      });

      // Update account nodes
      accountNodes.forEach(node => {
        node.pulse += node.pulseSpeed;

        // Gentle drift around base position
        node.x += node.vx;
        node.y += node.vy;

        const dx = node.x - node.baseX;
        const dy = node.y - node.baseY;
        if (Math.sqrt(dx * dx + dy * dy) > 35) {
          node.vx *= -1;
          node.vy *= -1;
        }

        // Mouse repulsion
        const mdx = node.x - mouse.x;
        const mdy = node.y - mouse.y;
        const mdist = Math.sqrt(mdx * mdx + mdy * mdy);
        if (mdist < 140 && mdist > 0) {
          const force = (140 - mdist) / 140 * 1.8;
          node.x += (mdx / mdist) * force;
          node.y += (mdy / mdist) * force;
        }
      });

      // Draw constellation lines between account nodes
      for (let i = 0; i < accountNodes.length; i++) {
        for (let j = i + 1; j < accountNodes.length; j++) {
          const a = accountNodes[i];
          const b = accountNodes[j];
          const dist = Math.hypot(a.x - b.x, a.y - b.y);

          const alpha = Math.max(0.04, 0.28 - (dist / (width * 0.8)));
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = `rgba(56, 189, 248, ${alpha})`;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }

      // Update & draw active packets
      for (let i = packets.length - 1; i >= 0; i--) {
        const pkt = packets[i];
        pkt.progress += pkt.speed;

        if (pkt.progress >= 1) {
          if (pkt.onComplete) pkt.onComplete();
          packets.splice(i, 1);
          continue;
        }

        const currX = pkt.from.x + (pkt.to.x - pkt.from.x) * pkt.progress;
        const currY = pkt.from.y + (pkt.to.y - pkt.from.y) * pkt.progress;

        pkt.trail.push({ x: currX, y: currY });
        if (pkt.trail.length > 8) pkt.trail.shift();

        // Draw packet trail
        ctx.beginPath();
        for (let t = 0; t < pkt.trail.length; t++) {
          const tp = pkt.trail[t];
          if (t === 0) ctx.moveTo(tp.x, tp.y);
          else ctx.lineTo(tp.x, tp.y);
        }
        ctx.strokeStyle = 'rgba(34, 197, 94, 0.4)';
        ctx.lineWidth = 2.5;
        ctx.stroke();

        // Draw packet head
        ctx.beginPath();
        ctx.arc(currX, currY, pkt.size, 0, Math.PI * 2);
        ctx.fillStyle = '#ffffff';
        ctx.shadowColor = '#22c55e';
        ctx.shadowBlur = 12;
        ctx.fill();
        ctx.shadowBlur = 0;
      }

      // Update & draw shockwaves
      for (let i = shockwaves.length - 1; i >= 0; i--) {
        const sw = shockwaves[i];
        sw.radius += 1.5;
        sw.alpha -= 0.025;

        if (sw.alpha <= 0 || sw.radius >= sw.maxRadius) {
          shockwaves.splice(i, 1);
          continue;
        }

        ctx.beginPath();
        ctx.arc(sw.x, sw.y, sw.radius, 0, Math.PI * 2);
        ctx.strokeStyle = sw.color.replace(/[\d\.]+\)$/, `${sw.alpha})`);
        ctx.lineWidth = 1.8;
        ctx.stroke();
      }

      // Draw Account Nodes
      accountNodes.forEach((node, idx) => {
        const isActive = (idx === activeSlotIndex);
        const pulseScale = 1 + Math.sin(node.pulse) * 0.15;
        const radius = (isActive ? 9 : 6.5) * pulseScale;

        // Outer halo
        const haloGradient = ctx.createRadialGradient(node.x, node.y, 0, node.x, node.y, radius * 2.8);
        haloGradient.addColorStop(0, node.color.replace(')', ', 0.35)').replace('rgb', 'rgba').replace('#22c55e', 'rgba(34,197,94,0.35)').replace('#38bdf8', 'rgba(56,189,248,0.35)').replace('#f59e0b', 'rgba(245,158,11,0.35)').replace('#c084fc', 'rgba(192,132,252,0.35)'));
        haloGradient.addColorStop(1, 'transparent');

        ctx.beginPath();
        ctx.arc(node.x, node.y, radius * 2.8, 0, Math.PI * 2);
        ctx.fillStyle = haloGradient;
        ctx.fill();

        // Solid core
        ctx.beginPath();
        ctx.arc(node.x, node.y, radius, 0, Math.PI * 2);
        ctx.fillStyle = node.color;
        ctx.fill();

        // Inner white glimmer
        ctx.beginPath();
        ctx.arc(node.x - radius * 0.3, node.y - radius * 0.3, radius * 0.35, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.fill();

        // Status & Label Text
        ctx.font = '10px ui-monospace, monospace';
        ctx.textAlign = 'center';
        ctx.fillStyle = isActive ? '#4ade80' : 'rgba(203, 213, 225, 0.75)';
        ctx.fillText(node.label, node.x, node.y + radius + 15);

        if (isActive) {
          ctx.font = '9px ui-monospace, monospace';
          ctx.fillStyle = '#22c55e';
          ctx.fillText('● ACTIVE', node.x, node.y + radius + 27);
        } else if (node.status === 'cooldown') {
          ctx.font = '9px ui-monospace, monospace';
          ctx.fillStyle = '#f59e0b';
          ctx.fillText('COOLING', node.x, node.y + radius + 27);
        }
      });

      animId = requestAnimationFrame(animate);
    }

    // Debounced window resize
    let resizeTimer = null;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(resize, 150);
    }, { passive: true });

    // Initial sizing
    resize();

    if (!prefersReducedMotion) {
      animId = requestAnimationFrame(animate);

      // Pause when hero is scrolled out of viewport
      if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              if (!isVisible) {
                isVisible = true;
                lastFailoverTime = Date.now();
                animId = requestAnimationFrame(animate);
              }
            } else {
              isVisible = false;
              if (animId) cancelAnimationFrame(animId);
            }
          });
        }, { threshold: 0.05 });

        observer.observe(heroSection);
      }

      // Pause when tab is hidden
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
          isVisible = false;
          if (animId) cancelAnimationFrame(animId);
        } else {
          isVisible = true;
          lastFailoverTime = Date.now();
          animId = requestAnimationFrame(animate);
        }
      });
    }
  }

  /* ==========================================================================
     3. Live Ticker / Keyword Rotation System
     ========================================================================== */

  function initHeroTicker(heroSection) {
    const tickerText = heroSection.querySelector('#heroTickerText');
    if (!tickerText) return;

    if (prefersReducedMotion) return; // Keep initial text static for reduced motion

    const simulationMessages = [
      'Slot #1 hit HTTP 429 ➔ Auto-swapped to Slot #2 in 0.84s',
      'Context preserved ➔ Session resumed with zero token loss',
      'Slot #4 cooling down ➔ Auto-re-queued for rotation in 12m',
      'Official Google TLS fingerprint ➔ 0 proxies · 0 ban risk',
      '5/5 Google slots active ➔ Continuous Antigravity coding'
    ];

    let messageIdx = 0;
    let tickerInterval = null;

    function step() {
      messageIdx = (messageIdx + 1) % simulationMessages.length;
      tickerText.classList.add('fade-out');

      setTimeout(() => {
        tickerText.textContent = simulationMessages[messageIdx];
        tickerText.classList.remove('fade-out');
        tickerText.classList.add('fade-in');

        setTimeout(() => {
          tickerText.classList.remove('fade-in');
        }, 250);
      }, 250);
    }

    tickerInterval = setInterval(step, 4200);

    // Pause ticker when hero is out of view
    if ('IntersectionObserver' in window) {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            if (!tickerInterval) tickerInterval = setInterval(step, 4200);
          } else {
            if (tickerInterval) {
              clearInterval(tickerInterval);
              tickerInterval = null;
            }
          }
        });
      }, { threshold: 0.1 });

      observer.observe(heroSection);
    }
  }

  /* ==========================================================================
     4. Navbar Active Link Underline Indicator
     ========================================================================== */

  function initNavbarIndicator() {
    const navLinksContainer = document.querySelector('.nav-links');
    const indicator = document.getElementById('navIndicator');
    if (!navLinksContainer || !indicator) return;

    const navLinks = navLinksContainer.querySelectorAll('.nav-link');
    if (!navLinks.length) return;

    function moveToLink(link) {
      if (!link) {
        indicator.style.opacity = '0';
        return;
      }
      const linkRect = link.getBoundingClientRect();
      const containerRect = navLinksContainer.getBoundingClientRect();

      const offsetLeft = linkRect.left - containerRect.left;
      const width = linkRect.width;

      indicator.style.transform = `translateX(${offsetLeft}px)`;
      indicator.style.width = `${width}px`;
      indicator.style.opacity = '1';
    }

    function syncActiveLink() {
      const activeLink = navLinksContainer.querySelector('.nav-link.active');
      if (activeLink && window.scrollY > 80) {
        moveToLink(activeLink);
      } else {
        indicator.style.opacity = '0';
      }
    }

    navLinks.forEach(link => {
      link.addEventListener('mouseenter', () => moveToLink(link));
    });

    navLinksContainer.addEventListener('mouseleave', () => {
      syncActiveLink();
    });

    // Update on scroll & resize
    window.addEventListener('scroll', syncActiveLink, { passive: true });
    window.addEventListener('resize', syncActiveLink, { passive: true });

    // Initial position
    setTimeout(syncActiveLink, 200);
  }

})();
