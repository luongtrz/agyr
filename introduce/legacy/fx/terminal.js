/**
 * agyr — Terminal Showcase Visual FX & Living Terminal Engine
 * introduce/fx/terminal.js
 *
 * Adds realistic terminal window chrome, dynamic ambient backglow halos,
 * CRT scanlines/reflection overlay, command typewriter & progressive line reveal,
 * pulsing active account marker, animated quota mini-meter bars,
 * and synchronized 429 failover alerts.
 */

(() => {
  'use strict';

  // State management
  let activeTimeouts = [];
  let isSectionVisible = false;
  let hasAutoPlayed = false;

  const prefersReducedMotion = () => {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  };

  const clearAllActiveTimeouts = () => {
    activeTimeouts.forEach(tId => clearTimeout(tId));
    activeTimeouts = [];
  };

  /* ==========================================================================
     1. DOM Injection & Window Chrome Setup
     ========================================================================== */

  function setupTerminalChrome() {
    const views = [
      { id: 'viewList', haloColor: 'rgba(34, 197, 94, 0.18)', shell: 'bash' },
      { id: 'viewRotate', haloColor: 'rgba(56, 189, 248, 0.18)', shell: 'daemon' }
    ];

    views.forEach(({ id, haloColor, shell }) => {
      const viewEl = document.getElementById(id);
      if (!viewEl) return;

      const wrapper = viewEl.querySelector('.terminal-wrapper');
      if (!wrapper) return;

      // 1. Ambient colored halo behind the terminal
      if (!viewEl.querySelector('.terminal-ambient-halo')) {
        const halo = document.createElement('div');
        halo.className = 'terminal-ambient-halo';
        halo.setAttribute('aria-hidden', 'true');
        halo.style.setProperty('--terminal-halo-color', haloColor);
        viewEl.insertBefore(halo, wrapper);
      }

      // 2. CRT Scanlines & Glass Sheen Overlay
      if (!wrapper.querySelector('.terminal-crt-scanlines')) {
        const scanlines = document.createElement('div');
        scanlines.className = 'terminal-crt-scanlines';
        scanlines.setAttribute('aria-hidden', 'true');
        wrapper.appendChild(scanlines);
      }

      if (!wrapper.querySelector('.terminal-glass-shine')) {
        const shine = document.createElement('div');
        shine.className = 'terminal-glass-shine';
        shine.setAttribute('aria-hidden', 'true');
        wrapper.appendChild(shine);
      }

      // 3. Shell Badge in Header Title
      const titleEl = wrapper.querySelector('.terminal-title');
      if (titleEl && !titleEl.querySelector('.terminal-shell-badge')) {
        const badge = document.createElement('span');
        badge.className = 'terminal-shell-badge';
        badge.textContent = shell;
        titleEl.appendChild(badge);
      }
    });

    setupStatusPills();
    setupCopyOutputButtons();
    setupActiveRowAndQuotaCells();
  }

  /* ==========================================================================
     2. Live Status Pills & Terminal Actions
     ========================================================================== */

  let statusPillList = null;
  let statusPillRotate = null;

  function setupStatusPills() {
    const viewList = document.getElementById('viewList');
    if (viewList && !viewList.querySelector('.term-status-pill')) {
      const header = viewList.querySelector('.terminal-header');
      const tools = viewList.querySelector('.terminal-tools');
      statusPillList = document.createElement('div');
      statusPillList.className = 'term-status-pill';
      statusPillList.innerHTML = '<span class="term-status-dot"></span><span class="term-status-text">LIVE · 5 ACCOUNTS</span>';
      if (tools && header) {
        header.insertBefore(statusPillList, tools);
      }
    }

    const viewRotate = document.getElementById('viewRotate');
    if (viewRotate && !viewRotate.querySelector('.term-status-pill')) {
      const header = viewRotate.querySelector('.terminal-header');
      const tools = viewRotate.querySelector('.terminal-tools');
      statusPillRotate = document.createElement('div');
      statusPillRotate.className = 'term-status-pill';
      statusPillRotate.innerHTML = '<span class="term-status-dot"></span><span class="term-status-text">FAILOVER READY</span>';
      if (tools && header) {
        header.insertBefore(statusPillRotate, tools);
      }
    }
  }

  function setupCopyOutputButtons() {
    const viewList = document.getElementById('viewList');
    const viewRotate = document.getElementById('viewRotate');

    const createCopyBtn = (screenId, label = 'Copy Output') => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn-term-copy';
      btn.setAttribute('aria-label', `Copy ${screenId} terminal text`);
      btn.setAttribute('title', 'Copy terminal output to clipboard');
      btn.innerHTML = `
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
        </svg>
        <span class="copy-lbl">${label}</span>
      `;

      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const screen = document.getElementById(screenId);
        if (!screen) return;
        const text = screen.innerText || screen.textContent || '';

        const onCopied = () => {
          btn.classList.add('copied');
          const lbl = btn.querySelector('.copy-lbl');
          if (lbl) lbl.textContent = 'Copied!';
          setTimeout(() => {
            btn.classList.remove('copied');
            if (lbl) lbl.textContent = label;
          }, 1800);
        };

        if (window.copyText) {
          window.copyText(text, btn);
          onCopied();
        } else if (navigator.clipboard && window.isSecureContext) {
          navigator.clipboard.writeText(text).then(onCopied).catch(() => {});
        } else {
          onCopied();
        }
      });

      return btn;
    };

    if (viewList) {
      const tools = viewList.querySelector('.terminal-tools');
      if (tools && !tools.querySelector('.btn-term-copy')) {
        tools.appendChild(createCopyBtn('terminalListScreen', 'Copy'));
      }
    }

    if (viewRotate) {
      const tools = viewRotate.querySelector('.terminal-tools');
      if (tools && !tools.querySelector('.btn-term-copy')) {
        tools.appendChild(createCopyBtn('terminalRotateScreen', 'Copy'));
      }
    }
  }

  /* ==========================================================================
     3. Active Account Row Marker & Quota Cells
     ========================================================================== */

  function setupActiveRowAndQuotaCells() {
    const tables = [document.getElementById('standardTable'), document.getElementById('claudeTable')];

    tables.forEach(table => {
      if (!table) return;

      const lines = table.querySelectorAll('.term-line');
      lines.forEach(line => {
        // Find active account row marked with '*'
        const star = line.querySelector('.txt-cyan');
        if (star && star.textContent.trim() === '*') {
          line.classList.add('active-account-line');
          star.classList.add('active-account-marker');
        }

        // Find percentage cells
        const colorSpans = line.querySelectorAll('.txt-green, .txt-yellow, .txt-red');
        colorSpans.forEach(span => {
          const text = span.textContent;
          const match = text.match(/^\s*(\d{1,3})%\s*$/);
          if (match) {
            const pct = parseInt(match[1], 10);
            span.classList.add('quota-pct-badge');
            span.dataset.targetPct = String(pct);
            span.dataset.origText = text;
            span.style.setProperty('--q-w', `${pct}%`);
          }
        });
      });
    });
  }

  function animateQuotaInLine(line) {
    if (prefersReducedMotion()) return;

    const badges = line.querySelectorAll('.quota-pct-badge');
    badges.forEach(badge => {
      const targetPct = parseInt(badge.dataset.targetPct, 10);
      const origText = badge.dataset.origText;
      if (isNaN(targetPct) || !origText) return;

      // Reset width to 0 and expand smoothly
      badge.style.setProperty('--q-w', '0%');
      requestAnimationFrame(() => {
        badge.style.setProperty('--q-w', `${targetPct}%`);
      });

      // Count up numbers preserving exact character spacing
      const steps = 8;
      const stepInterval = 28;
      let currentStep = 0;

      const timer = setInterval(() => {
        currentStep++;
        const currentVal = Math.round((targetPct * currentStep) / steps);
        const formatted = String(currentVal) + '%';
        badge.textContent = formatted.padStart(origText.length, ' ');

        if (currentStep >= steps) {
          clearInterval(timer);
          badge.textContent = origText;
        }
      }, stepInterval);
    });
  }

  /* ==========================================================================
     4. Typewriter & Progressive Table Line Reveal
     ========================================================================== */

  let isTyping = false;

  function typeCommand(element, targetText, onComplete, speed = 24) {
    if (!element) {
      if (onComplete) onComplete();
      return;
    }

    if (prefersReducedMotion()) {
      element.textContent = targetText;
      if (onComplete) onComplete();
      return;
    }

    isTyping = true;
    element.textContent = '';

    const cursor = document.createElement('span');
    cursor.className = 'term-cmd-cursor';
    cursor.textContent = '▋';
    cursor.setAttribute('aria-hidden', 'true');
    element.appendChild(cursor);

    let idx = 0;

    const tick = () => {
      if (!isTyping) {
        element.textContent = targetText;
        if (onComplete) onComplete();
        return;
      }

      if (idx < targetText.length) {
        idx++;
        element.textContent = targetText.slice(0, idx);
        element.appendChild(cursor);
        const tId = setTimeout(tick, speed);
        activeTimeouts.push(tId);
      } else {
        // Brief pause with blinking cursor
        const tId = setTimeout(() => {
          if (cursor.parentNode) cursor.parentNode.removeChild(cursor);
          element.textContent = targetText;
          isTyping = false;
          if (onComplete) onComplete();
        }, 120);
        activeTimeouts.push(tId);
      }
    };

    tick();
  }

  function cascadeRevealTable(tableWrapper) {
    if (!tableWrapper) return;

    const lines = tableWrapper.querySelectorAll('.term-line');
    if (!lines.length) return;

    if (prefersReducedMotion()) {
      tableWrapper.classList.remove('term-typing');
      lines.forEach(l => l.classList.add('revealed'));
      return;
    }

    tableWrapper.classList.add('term-typing');
    lines.forEach(l => l.classList.remove('revealed'));

    lines.forEach((line, index) => {
      const tId = setTimeout(() => {
        line.classList.add('revealed');
        animateQuotaInLine(line);
      }, index * 32);
      activeTimeouts.push(tId);
    });

    const finishTimeout = setTimeout(() => {
      tableWrapper.classList.remove('term-typing');
    }, (lines.length + 1) * 32);
    activeTimeouts.push(finishTimeout);
  }

  function runListShowcaseSequence() {
    clearAllActiveTimeouts();

    const displayedListCmd = document.getElementById('displayedListCmd');
    const standardTable = document.getElementById('standardTable');
    const claudeTable = document.getElementById('claudeTable');
    if (!displayedListCmd) return;

    const isClaude = claudeTable && claudeTable.style.display !== 'none';
    const activeTable = isClaude ? claudeTable : standardTable;
    const targetCmd = isClaude ? 'agyr list --claude' : 'agyr list';

    typeCommand(displayedListCmd, targetCmd, () => {
      cascadeRevealTable(activeTable);
    }, 22);
  }

  /* ==========================================================================
     5. Autonomous 429 Failover Step Synchronizer
     ========================================================================== */

  function setupRotateFailoverObserver() {
    const rotateScreen = document.getElementById('terminalRotateScreen');
    const viewRotate = document.getElementById('viewRotate');
    if (!rotateScreen || !viewRotate) return;

    const rotateWrapper = viewRotate.querySelector('.terminal-wrapper');
    const rotateHalo = viewRotate.querySelector('.terminal-ambient-halo');

    const updatePill = (statusClass, text) => {
      if (!statusPillRotate) return;
      statusPillRotate.className = `term-status-pill ${statusClass}`.trim();
      const txt = statusPillRotate.querySelector('.term-status-text');
      if (txt) txt.textContent = text;
    };

    const updateAmbientGlow = (color) => {
      if (rotateWrapper) rotateWrapper.style.setProperty('--terminal-glow-color', color);
      if (rotateHalo) rotateHalo.style.setProperty('--terminal-halo-color', color);
    };

    const resetRotateVisuals = () => {
      updatePill('', 'FAILOVER READY');
      if (rotateWrapper) rotateWrapper.style.removeProperty('--terminal-glow-color');
      if (rotateHalo) rotateHalo.style.removeProperty('--terminal-halo-color');
      const steps = rotateScreen.querySelectorAll('.anim-step');
      steps.forEach(s => s.classList.remove('term-line-429', 'term-line-switch', 'term-line-ok'));
    };

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          const target = mutation.target;

          if (target.classList.contains('step-3') && target.classList.contains('visible')) {
            target.classList.add('term-line-429');
            updatePill('status-red', '429 QUOTA WALL HIT');
            updateAmbientGlow('rgba(239, 68, 68, 0.32)');
          } else if (target.classList.contains('step-4') && target.classList.contains('visible')) {
            target.classList.add('term-line-switch');
            updatePill('status-amber', 'FAILOVER: WORK-1 ➔ WORK-2');
            updateAmbientGlow('rgba(245, 158, 11, 0.32)');
          } else if (target.classList.contains('step-5') && target.classList.contains('visible')) {
            updatePill('status-purple', 'CONTEXT RESUMED (9c4e1a80)');
            updateAmbientGlow('rgba(192, 132, 252, 0.32)');
          } else if (target.classList.contains('step-6') && target.classList.contains('visible')) {
            target.classList.add('term-line-ok');
            updatePill('', 'RESUME OK · 0 TOKENS LOST');
            updateAmbientGlow('rgba(34, 197, 94, 0.32)');
          } else if (target.classList.contains('step-1') && !target.classList.contains('visible')) {
            // When step-1 loses visible, flow is being reset
            resetRotateVisuals();
          }
        }
      });
    });

    observer.observe(rotateScreen, {
      attributes: true,
      subtree: true,
      attributeFilter: ['class']
    });

    // Replay button interaction
    const replayBtn = document.getElementById('btnReplayRotate');
    if (replayBtn) {
      replayBtn.addEventListener('click', () => {
        replayBtn.classList.add('replaying');
        setTimeout(() => replayBtn.classList.remove('replaying'), 800);

        // Fast typewriter on the initial command
        const cmdEl = rotateScreen.querySelector('.term-line .txt-cmd');
        if (cmdEl && !prefersReducedMotion()) {
          const targetCmd = 'agy-run --add-dir . --prompt "Refactor auth middleware"';
          typeCommand(cmdEl, targetCmd, null, 4);
        }
      });
    }
  }

  /* ==========================================================================
     6. Event Handlers & View Synchronization
     ========================================================================== */

  function setupEventSync() {
    const btnShowcaseList = document.getElementById('btnShowcaseList');
    const btnShowcaseRotate = document.getElementById('btnShowcaseRotate');
    const toggleStandard = document.getElementById('toggleStandardView');
    const toggleClaude = document.getElementById('toggleClaudeView');

    if (btnShowcaseList) {
      btnShowcaseList.addEventListener('click', () => {
        runListShowcaseSequence();
      });
    }

    if (btnShowcaseRotate) {
      btnShowcaseRotate.addEventListener('click', () => {
        clearAllActiveTimeouts();
        const rotateScreen = document.getElementById('terminalRotateScreen');
        if (rotateScreen && !prefersReducedMotion()) {
          const cmdEl = rotateScreen.querySelector('.term-line .txt-cmd');
          if (cmdEl) {
            typeCommand(cmdEl, 'agy-run --add-dir . --prompt "Refactor auth middleware"', null, 4);
          }
        }
      });
    }

    if (toggleStandard) {
      toggleStandard.addEventListener('click', () => {
        clearAllActiveTimeouts();
        const displayedListCmd = document.getElementById('displayedListCmd');
        const standardTable = document.getElementById('standardTable');
        if (displayedListCmd && standardTable) {
          typeCommand(displayedListCmd, 'agyr list', () => {
            cascadeRevealTable(standardTable);
          }, 20);
        }
      });
    }

    if (toggleClaude) {
      toggleClaude.addEventListener('click', () => {
        clearAllActiveTimeouts();
        const displayedListCmd = document.getElementById('displayedListCmd');
        const claudeTable = document.getElementById('claudeTable');
        if (displayedListCmd && claudeTable) {
          typeCommand(displayedListCmd, 'agyr list --claude', () => {
            cascadeRevealTable(claudeTable);
          }, 18);
        }
      });
    }

    // Pause on visibility change
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        clearAllActiveTimeouts();
        isTyping = false;
        // Make sure table is visible immediately if user switches away
        const standardTable = document.getElementById('standardTable');
        const claudeTable = document.getElementById('claudeTable');
        if (standardTable) standardTable.classList.remove('term-typing');
        if (claudeTable) claudeTable.classList.remove('term-typing');
      }
    });
  }

  /* ==========================================================================
     7. IntersectionObserver for Viewport Entry
     ========================================================================== */

  function setupIntersectionTrigger() {
    const showcaseSection = document.getElementById('demo');
    if (!showcaseSection) return;

    if (!('IntersectionObserver' in window)) {
      runListShowcaseSequence();
      return;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          isSectionVisible = true;
          if (!hasAutoPlayed) {
            hasAutoPlayed = true;
            runListShowcaseSequence();
          }
        } else {
          isSectionVisible = false;
        }
      });
    }, {
      rootMargin: '-10% 0px -10% 0px',
      threshold: 0.15
    });

    observer.observe(showcaseSection);
  }

  /* ==========================================================================
     8. Initialization Entrypoint
     ========================================================================== */

  function init() {
    setupTerminalChrome();
    setupRotateFailoverObserver();
    setupEventSync();
    setupIntersectionTrigger();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
