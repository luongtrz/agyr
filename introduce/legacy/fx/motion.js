/**
 * agyr — Global Scroll Motion & Micro-Interactions (fx/motion.js)
 * High-performance, zero-dependency visual polish for Antigravity CLI showcase.
 * Degrades 100% gracefully: all content remains fully visible without JS or
 * when prefers-reduced-motion is requested.
 */

(function () {
  'use strict';

  // Fast check: respect user preferences for reduced motion
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Track tab visibility to pause unnecessary RAF work
  let isTabVisible = !document.hidden;
  document.addEventListener('visibilitychange', () => {
    isTabVisible = !document.hidden;
  });

  /* ==========================================================================
     1. Scroll Progress Bar (Thin Gradient Line at Top)
     ========================================================================== */
  function initScrollProgressBar() {
    const track = document.createElement('div');
    track.className = 'scroll-progress-track';
    track.setAttribute('aria-hidden', 'true');

    const bar = document.createElement('div');
    bar.className = 'scroll-progress-bar';
    track.appendChild(bar);
    document.body.appendChild(track);

    let isTicking = false;

    const updateProgress = () => {
      if (!isTabVisible) {
        isTicking = false;
        return;
      }
      const doc = document.documentElement;
      const totalScroll = doc.scrollHeight - window.innerHeight;
      const progress = totalScroll > 0 ? Math.min(Math.max(window.scrollY / totalScroll, 0), 1) : 0;
      bar.style.transform = `scaleX(${progress})`;
      isTicking = false;
    };

    window.addEventListener(
      'scroll',
      () => {
        if (!isTicking) {
          window.requestAnimationFrame(updateProgress);
          isTicking = true;
        }
      },
      { passive: true }
    );

    window.addEventListener(
      'resize',
      () => {
        if (!isTicking) {
          window.requestAnimationFrame(updateProgress);
          isTicking = true;
        }
      },
      { passive: true }
    );

    updateProgress();
  }

  /* ==========================================================================
     2. Section Heading Accent Line Draw
     ========================================================================== */
  function initSectionHeadingLines() {
    const headers = document.querySelectorAll('.section-header');
    headers.forEach((header) => {
      const title = header.querySelector('.section-title');
      if (title && !header.querySelector('.motion-heading-line')) {
        const line = document.createElement('div');
        line.className = 'motion-heading-line';
        line.setAttribute('aria-hidden', 'true');
        title.insertAdjacentElement('afterend', line);
      }
    });
  }

  /* ==========================================================================
     3. IntersectionObserver-based Scroll Reveal
     ========================================================================== */
  function initScrollReveals() {
    if (prefersReducedMotion || !('IntersectionObserver' in window)) {
      return;
    }

    const revealObserver = new IntersectionObserver(
      (entries, observer) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const el = entry.target;
            observer.unobserve(el);
            el.classList.add('motion-in-view');

            // Once transition finishes, switch to .motion-revealed so native hover transforms are instantaneous
            const cleanUp = () => {
              el.classList.remove('motion-reveal');
              el.classList.add('motion-revealed');
              el.style.transitionDelay = '';
              el.style.willChange = 'auto';
            };

            el.addEventListener('transitionend', function handler(e) {
              if (e.propertyName === 'opacity' || e.propertyName === 'transform') {
                el.removeEventListener('transitionend', handler);
                cleanUp();
              }
            });

            // Fallback timeout in case transitionend does not fire
            const delayMs = parseFloat(el.style.transitionDelay || 0) * 1000;
            setTimeout(cleanUp, delayMs + 750);
          }
        });
      },
      {
        rootMargin: '0px 0px -40px 0px',
        threshold: 0.08
      }
    );

    // Group elements by grid/container to apply elegant staggered delays
    const groups = [
      { selector: '.section-header', stagger: 0 },
      { selector: '.metrics-grid .metric-card', stagger: 70 },
      { selector: '.showcase-section .terminal-wrapper', stagger: 0 },
      { selector: '.usp-grid .usp-card', stagger: 80 },
      { selector: '.comparison-table tbody tr', stagger: 60 },
      { selector: '.steps-grid .step-card', stagger: 80 },
      { selector: '.orchestration-card', stagger: 0 },
      { selector: '.commands-grid .cmd-card', stagger: 35 },
      { selector: '.platforms-grid .platform-card', stagger: 100 },
      { selector: '.faq-accordion .faq-item', stagger: 55 },
      { selector: '.cta-banner', stagger: 0 }
    ];

    groups.forEach(({ selector, stagger }) => {
      const items = document.querySelectorAll(selector);
      items.forEach((item, idx) => {
        item.classList.add('motion-reveal');
        if (stagger > 0) {
          // Cap stagger delay to 350ms so distant items don't take too long to appear
          const delay = Math.min(idx * stagger, 350);
          item.style.transitionDelay = `${delay}ms`;
        }
        revealObserver.observe(item);
      });
    });
  }

  /* ==========================================================================
     4. Animated Count-Up for Numeric Stats
     ========================================================================== */
  function initNumericCounters() {
    if (prefersReducedMotion || !('IntersectionObserver' in window)) return;

    const cards = document.querySelectorAll('.metric-card');
    if (!cards.length) return;

    const counterObserver = new IntersectionObserver(
      (entries, obs) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            obs.unobserve(entry.target);
            const valEl = entry.target.querySelector('.metric-value');
            if (!valEl) return;

            const text = valEl.textContent.trim();
            if (text === '100%') {
              animateCount(valEl, 0, 100, 1200, '', '%');
            } else if (text === '0 MB') {
              animateCount(valEl, 12, 0, 800, '', ' MB');
            } else if (text === '0%') {
              animateCount(valEl, 6, 0, 800, '', '%');
            } else if (text === '< 1s') {
              animateSubSecond(valEl);
            }
          }
        });
      },
      { threshold: 0.25 }
    );

    cards.forEach((card) => counterObserver.observe(card));
  }

  function animateCount(el, start, end, duration, prefix = '', suffix = '') {
    const startTime = performance.now();
    const diff = end - start;

    const update = (now) => {
      if (!isTabVisible) {
        el.textContent = `${prefix}${end}${suffix}`;
        return;
      }
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Cubic ease-out
      const ease = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(start + diff * ease);
      el.textContent = `${prefix}${current}${suffix}`;

      if (progress < 1) {
        window.requestAnimationFrame(update);
      } else {
        el.textContent = `${prefix}${end}${suffix}`;
      }
    };

    window.requestAnimationFrame(update);
  }

  function animateSubSecond(el) {
    const startTime = performance.now();
    const duration = 850;

    const update = (now) => {
      if (!isTabVisible) {
        el.textContent = '< 1s';
        return;
      }
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      if (progress < 1) {
        const val = (2.8 - progress * 2.0).toFixed(1);
        el.textContent = `${val}s`;
        window.requestAnimationFrame(update);
      } else {
        el.textContent = '< 1s';
      }
    };

    window.requestAnimationFrame(update);
  }

  /* ==========================================================================
     5. Mouse-Follow Spotlight Glow on Cards
     ========================================================================== */
  function initCardSpotlight() {
    if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;

    const selector =
      '.usp-card, .cmd-card, .step-card, .platform-card, .metric-card, .orchestration-card';
    const cards = document.querySelectorAll(selector);

    cards.forEach((card) => {
      card.classList.add('motion-spotlight');

      let rafId = null;

      const onPointerMove = (e) => {
        if (!isTabVisible) return;
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        if (rafId) window.cancelAnimationFrame(rafId);
        rafId = window.requestAnimationFrame(() => {
          card.style.setProperty('--mx', `${x.toFixed(1)}px`);
          card.style.setProperty('--my', `${y.toFixed(1)}px`);
        });
      };

      const onPointerLeave = () => {
        if (rafId) window.cancelAnimationFrame(rafId);
        card.style.setProperty('--mx', '-9999px');
        card.style.setProperty('--my', '-9999px');
      };

      card.addEventListener('pointermove', onPointerMove, { passive: true });
      card.addEventListener('pointerleave', onPointerLeave, { passive: true });
    });
  }

  /* ==========================================================================
     6. Subtle 3D Tilt for USP Cards (Desktop / Fine Pointer Only)
     ========================================================================== */
  function initUspTilt() {
    if (prefersReducedMotion || !window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      return;
    }

    const cards = document.querySelectorAll('.usp-card');
    cards.forEach((card) => {
      let rafId = null;
      let targetX = 0;
      let targetY = 0;
      let currentX = 0;
      let currentY = 0;
      let isHovering = false;

      const updateTilt = () => {
        if (!isHovering || !isTabVisible) return;
        // Smooth linear interpolation (lerp)
        currentX += (targetX - currentX) * 0.16;
        currentY += (targetY - currentY) * 0.16;

        card.style.transform = `perspective(1000px) rotateX(${currentX.toFixed(2)}deg) rotateY(${currentY.toFixed(2)}deg) translateY(-4px)`;

        rafId = window.requestAnimationFrame(updateTilt);
      };

      const onPointerMove = (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        // Subtle angle limit: -4.5deg to +4.5deg
        targetX = ((y - centerY) / centerY) * -4.5;
        targetY = ((x - centerX) / centerX) * 4.5;

        if (!isHovering) {
          isHovering = true;
          card.classList.add('is-tilting');
          updateTilt();
        }
      };

      const onPointerLeave = () => {
        isHovering = false;
        if (rafId) window.cancelAnimationFrame(rafId);
        card.classList.remove('is-tilting');
        card.style.transform = '';
        currentX = 0;
        currentY = 0;
        targetX = 0;
        targetY = 0;
      };

      card.addEventListener('pointermove', onPointerMove, { passive: true });
      card.addEventListener('pointerleave', onPointerLeave, { passive: true });
    });
  }

  /* ==========================================================================
     7. Ripple & Press Feedback on Buttons
     ========================================================================== */
  function initRippleFeedback() {
    if (prefersReducedMotion) return;

    const btnSelector =
      '.btn, .btn-copy, .btn-copy-code, .btn-copy-sm, .tab-btn, .showcase-nav-btn, .filter-btn, .btn-tool, .btn-toggle';

    document.addEventListener('click', (e) => {
      const btn = e.target.closest(btnSelector);
      if (!btn) return;

      btn.classList.add('motion-ripple-host');

      const rect = btn.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;

      const ripple = document.createElement('span');
      ripple.className = 'motion-ripple';
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;

      const size = Math.max(rect.width, rect.height) * 2.2;
      ripple.style.width = `${size}px`;
      ripple.style.height = `${size}px`;

      btn.appendChild(ripple);

      ripple.addEventListener('animationend', () => {
        ripple.remove();
      });
      setTimeout(() => {
        if (ripple.parentNode) ripple.remove();
      }, 650);
    });
  }

  /* ==========================================================================
     8. Polished Floating "Copied!" Toast (Non-intrusive addition)
     ========================================================================== */
  let toastTimer = null;

  function showCopiedToast(copiedText) {
    let container = document.querySelector('.motion-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'motion-toast-container';
      container.setAttribute('aria-live', 'polite');
      container.setAttribute('aria-atomic', 'true');
      document.body.appendChild(container);
    }

    container.innerHTML = '';
    if (toastTimer) clearTimeout(toastTimer);

    const toast = document.createElement('div');
    toast.className = 'motion-toast';

    const icon = document.createElement('span');
    icon.className = 'motion-toast-icon';
    icon.innerHTML = `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>`;

    const textSpan = document.createElement('span');
    textSpan.className = 'motion-toast-text';
    textSpan.textContent = 'Copied to clipboard';

    toast.appendChild(icon);
    toast.appendChild(textSpan);

    if (copiedText && copiedText.trim().length > 0) {
      const snippet = document.createElement('span');
      snippet.className = 'motion-toast-code';
      snippet.textContent = copiedText.trim();
      toast.appendChild(snippet);
    }

    container.appendChild(toast);

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        toast.classList.add('show');
      });
    });

    toastTimer = setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 350);
    }, 2200);
  }

  function initToastListener() {
    document.addEventListener('click', (e) => {
      const copyBtn = e.target.closest('[data-copy]');
      if (copyBtn) {
        const text = copyBtn.getAttribute('data-copy');
        showCopiedToast(text);
      }
    });
  }

  /* ==========================================================================
     Main Initialization
     ========================================================================== */
  function init() {
    initScrollProgressBar();
    initSectionHeadingLines();
    initScrollReveals();
    initNumericCounters();
    initCardSpotlight();
    initUspTilt();
    initRippleFeedback();
    initToastListener();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
