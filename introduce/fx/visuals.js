/**
 * visuals.js — Rich static visuals & section polish for agyr landing page
 * Part of the parallel polish suite.
 * Injects enhanced inline SVGs, platform tags, quickstart step enhancements,
 * comparison badges, orchestration workflow strip, and floating back-to-top button.
 */

(function initVisuals() {
  if (typeof window === 'undefined') return;

  const isReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function runSetup() {
    enhanceComparisonBadges();
    enhanceQuickstartSteps();
    enhancePlatformCards();
    enhanceUspCards();
    enhanceOrchestrationSection();
    injectBackToTop();
    injectAmbientGlowOrbs();
  }

  /* ==========================================================================
     1. Comparison Table: Status Badges with SVG Check / Cross / Warn Icons
     ========================================================================== */
  function enhanceComparisonBadges() {
    const badges = document.querySelectorAll('.comparison-table .status-badge');
    if (!badges || badges.length === 0) return;

    badges.forEach((badge) => {
      if (badge.querySelector('.status-badge-icon')) return; // Already enhanced

      const isGreen = badge.classList.contains('badge-green');
      const isRed = badge.classList.contains('badge-red');
      const isAmber = badge.classList.contains('badge-amber');
      const isDim = badge.classList.contains('badge-dim');

      let iconSvg = '';
      if (isGreen) {
        iconSvg = `<svg class="status-badge-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
      } else if (isRed) {
        iconSvg = `<svg class="status-badge-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>`;
      } else if (isAmber) {
        iconSvg = `<svg class="status-badge-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>`;
      } else if (isDim) {
        iconSvg = `<svg class="status-badge-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="8" y1="12" x2="16" y2="12"></line></svg>`;
      }

      if (iconSvg) {
        badge.insertAdjacentHTML('afterbegin', iconSvg);
      }
    });
  }

  /* ==========================================================================
     2. Quickstart Steps: Rich Step Numbers with Themed Icons
     ========================================================================== */
  function enhanceQuickstartSteps() {
    const stepCards = document.querySelectorAll('.steps-grid .step-card');
    if (!stepCards || stepCards.length === 0) return;

    const stepIcons = [
      // Step 1: Sign-in / Key
      `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="7.5" cy="15.5" r="4.5"/><path d="m11 12 7.5-7.5a1.5 1.5 0 0 1 2 0l1.5 1.5a1.5 1.5 0 0 1 0 2L20.5 9.5"/><path d="m15.5 7.5 2 2"/></svg>`,
      // Step 2: Add Account / Multi-user
      `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>`,
      // Step 3: Quota Monitor / Dashboard
      `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2v4M4.93 4.93l2.83 2.83M2 12h4M4.93 19.07l2.83-2.83M12 22v-4M19.07 19.07l-2.83-2.83M22 12h-4M19.07 4.93l-2.83 2.83"/></svg>`,
      // Step 4: Automated Failover / Lightning
      `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`
    ];

    stepCards.forEach((card, index) => {
      const stepNumber = card.querySelector('.step-number');
      if (!stepNumber || stepNumber.querySelector('.step-icon-badge')) return;

      const numText = stepNumber.textContent.trim();
      const icon = stepIcons[index] || stepIcons[0];

      stepNumber.innerHTML = `
        <span class="step-num-text">${numText}</span>
        <span class="step-icon-badge" aria-hidden="true">${icon}</span>
      `;
    });
  }

  /* ==========================================================================
     3. Platform Cards: Native Backend Badges & Feature Bullets
     ========================================================================== */
  function enhancePlatformCards() {
    const cards = document.querySelectorAll('.platforms-grid .platform-card');
    if (!cards || cards.length === 0) return;

    cards.forEach((card, idx) => {
      const header = card.querySelector('.platform-header');
      if (header && !header.querySelector('.platform-chip')) {
        const chip = document.createElement('span');
        chip.className = 'platform-chip ' + (idx === 0 ? 'chip-linux' : 'chip-win');
        chip.textContent = idx === 0 ? 'D-Bus Keyring Isolation' : 'Native WinCred & DPAPI';
        header.appendChild(chip);
      }

      // Feature bullet icons
      const listItems = card.querySelectorAll('.platform-features li');
      const strokeColor = idx === 0 ? '#22c55e' : '#38bdf8';
      listItems.forEach((li) => {
        if (li.querySelector('.plat-bullet')) return;
        const bullet = document.createElement('span');
        bullet.className = 'plat-bullet';
        bullet.setAttribute('aria-hidden', 'true');
        bullet.innerHTML = `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="${strokeColor}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
        li.insertAdjacentElement('afterbegin', bullet);
      });
    });
  }

  /* ==========================================================================
     4. USP Cards: High-Tech Badges & Ambient Watermark Icons
     ========================================================================== */
  function enhanceUspCards() {
    const uspCards = document.querySelectorAll('.usp-grid .usp-card');
    if (!uspCards || uspCards.length === 0) return;

    const badgesData = [
      {
        label: '100% On-Device',
        cls: 'usp-badge-emerald',
        icon: `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`,
        watermark: `<svg width="120" height="120" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`
      },
      {
        label: 'Authentic Fingerprint',
        cls: 'usp-badge-blue',
        icon: `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>`,
        watermark: `<svg width="120" height="120" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`
      },
      {
        label: 'Bottleneck Heuristics',
        cls: 'usp-badge-purple',
        icon: `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>`,
        watermark: `<svg width="120" height="120" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>`
      }
    ];

    uspCards.forEach((card, i) => {
      if (card.querySelector('.usp-top-badge')) return;

      const data = badgesData[i] || badgesData[0];

      // Top pill
      const badgeEl = document.createElement('div');
      badgeEl.className = `usp-top-badge ${data.cls}`;
      badgeEl.innerHTML = `${data.icon}<span>${data.label}</span>`;
      card.insertAdjacentElement('afterbegin', badgeEl);

      // Background watermark
      const wm = document.createElement('div');
      wm.className = `usp-watermark ${data.cls}`;
      wm.setAttribute('aria-hidden', 'true');
      wm.innerHTML = data.watermark;
      card.appendChild(wm);
    });
  }

  /* ==========================================================================
     5. AI Orchestration: Visual Pipeline Diagram
     ========================================================================== */
  function enhanceOrchestrationSection() {
    const orchInfo = document.querySelector('.orchestration-section .orchestration-info');
    if (!orchInfo || orchInfo.querySelector('.agent-workflow-strip')) return;

    const agentFeatures = orchInfo.querySelector('.agent-features');
    if (!agentFeatures) return;

    const strip = document.createElement('div');
    strip.className = 'agent-workflow-strip';
    strip.innerHTML = `
      <div class="wf-step">
        <div class="wf-pill wf-claude">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="9"/>
            <circle cx="12" cy="12" r="3"/>
          </svg>
          <span>Claude / Gemini</span>
        </div>
        <span class="wf-role">Architect &amp; Reviewer</span>
      </div>

      <div class="wf-arrow" aria-hidden="true">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="4" y1="12" x2="20" y2="12"></line>
          <polyline points="14 6 20 12 14 18"></polyline>
        </svg>
      </div>

      <div class="wf-step">
        <div class="wf-pill wf-agy">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <polyline points="4 17 10 11 4 5"></polyline>
            <line x1="12" y1="19" x2="20" y2="19"></line>
          </svg>
          <span>agy-task</span>
        </div>
        <span class="wf-role">Dedicated Coder</span>
      </div>

      <div class="wf-arrow" aria-hidden="true">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="4" y1="12" x2="20" y2="12"></line>
          <polyline points="14 6 20 12 14 18"></polyline>
        </svg>
      </div>

      <div class="wf-step">
        <div class="wf-pill wf-agyr">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <polyline points="23 4 23 10 17 10"></polyline>
            <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path>
          </svg>
          <span>agyr auto</span>
        </div>
        <span class="wf-role">Zero 429 Blocker</span>
      </div>
    `;

    agentFeatures.insertAdjacentElement('beforebegin', strip);
  }

  /* ==========================================================================
     6. Floating Back-to-Top Button
     ========================================================================== */
  function injectBackToTop() {
    if (document.getElementById('agyrBackToTop')) return;

    const btn = document.createElement('button');
    btn.id = 'agyrBackToTop';
    btn.className = 'back-to-top';
    btn.setAttribute('aria-label', 'Back to top of page');
    btn.setAttribute('title', 'Back to top');
    btn.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <polyline points="18 15 12 9 6 15"></polyline>
      </svg>
    `;

    document.body.appendChild(btn);

    btn.addEventListener('click', () => {
      window.scrollTo({
        top: 0,
        behavior: isReducedMotion ? 'auto' : 'smooth'
      });
    });

    let isScrolling = false;
    window.addEventListener('scroll', () => {
      if (!isScrolling) {
        window.requestAnimationFrame(() => {
          const scrollPos = window.pageYOffset || document.documentElement.scrollTop || 0;
          if (scrollPos > 600) {
            btn.classList.add('visible');
          } else {
            btn.classList.remove('visible');
          }
          isScrolling = false;
        });
        isScrolling = true;
      }
    }, { passive: true });
  }

  /* ==========================================================================
     7. Ambient Glow Orbs for Lower Sections
     ========================================================================== */
  function injectAmbientGlowOrbs() {
    const sectionsWithGlow = [
      { id: 'features', color: 'emerald', top: '15%', left: '85%' },
      { id: 'comparison', color: 'cyan', top: '25%', left: '10%' },
      { id: 'agent-orchestration', color: 'purple', top: '20%', left: '90%' },
      { id: 'cli-reference', color: 'emerald', top: '40%', left: '5%' }
    ];

    sectionsWithGlow.forEach(({ id, color, top, left }) => {
      const section = document.getElementById(id);
      if (!section || section.querySelector(`.visuals-orb-${color}`)) return;

      const orb = document.createElement('div');
      orb.className = `visuals-orb visuals-orb-${color}`;
      orb.setAttribute('aria-hidden', 'true');
      orb.style.top = top;
      orb.style.left = left;
      section.style.position = 'relative';
      section.insertAdjacentElement('afterbegin', orb);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', runSetup);
  } else {
    runSetup();
  }
})();
