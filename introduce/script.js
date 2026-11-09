/**
 * agyr — Developer Landing Page Interactions
 * Handles copy-to-clipboard, terminal showcase toggles & animations,
 * CLI reference search/filters, and mobile navigation.
 */

document.addEventListener('DOMContentLoaded', () => {
  initClipboard();
  initInstallTabs();
  initShowcase();
  initRotateAnimation();
  initCommandFilters();
  initNavigation();
});

/* ==========================================================================
   1. Copy to Clipboard System
   ========================================================================== */

function copyText(text, triggerBtn) {
  if (!text) return;

  const performFeedback = () => {
    if (!triggerBtn) return;
    triggerBtn.classList.add('copied');
    const label = triggerBtn.querySelector('.copy-text');
    const originalText = label ? label.textContent : '';
    if (label) label.textContent = 'Copied!';

    setTimeout(() => {
      triggerBtn.classList.remove('copied');
      if (label) label.textContent = originalText;
    }, 2000);
  };

  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(performFeedback).catch(() => {
      fallbackCopy(text, performFeedback);
    });
  } else {
    fallbackCopy(text, performFeedback);
  }
}

function fallbackCopy(text, callback) {
  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.style.position = 'fixed';
  textArea.style.left = '-999999px';
  textArea.style.top = '-999999px';
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  try {
    document.execCommand('copy');
    if (callback) callback();
  } catch (err) {
    console.error('Fallback copy failed', err);
  }
  document.body.removeChild(textArea);
}

function initClipboard() {
  document.addEventListener('click', (e) => {
    const copyBtn = e.target.closest('[data-copy]');
    if (copyBtn) {
      const textToCopy = copyBtn.getAttribute('data-copy');
      copyText(textToCopy, copyBtn);
    }
  });
}

/* ==========================================================================
   2. Install Box Tabs (One-Line vs Manual Clone)
   ========================================================================== */

function initInstallTabs() {
  const tabCurl = document.getElementById('tab-curl');
  const tabClone = document.getElementById('tab-clone');
  const cmdContainer = document.getElementById('installCmdText');
  const copyBtn = document.getElementById('copyInstallBtn');

  if (!tabCurl || !tabClone || !cmdContainer || !copyBtn) return;

  const commands = {
    curl: 'curl -fsSL https://raw.githubusercontent.com/luongtrz/rotate-agy/main/install.sh | bash',
    clone: 'git clone https://github.com/luongtrz/rotate-agy.git ~/tools/agy-acct && bash ~/tools/agy-acct/install.sh'
  };

  const setTab = (activeTab, inactiveTab, key) => {
    activeTab.classList.add('active');
    activeTab.setAttribute('aria-selected', 'true');
    inactiveTab.classList.remove('active');
    inactiveTab.setAttribute('aria-selected', 'false');

    const cmdText = commands[key];
    cmdContainer.innerHTML = `<span class="prompt-symbol">$</span> <span class="cmd-text">${cmdText}</span>`;
    copyBtn.setAttribute('data-copy', cmdText);
  };

  tabCurl.addEventListener('click', () => setTab(tabCurl, tabClone, 'curl'));
  tabClone.addEventListener('click', () => setTab(tabClone, tabCurl, 'clone'));
}

/* ==========================================================================
   3. Terminal Showcase Controls & View Toggles
   ========================================================================== */

function initShowcase() {
  const btnShowcaseList = document.getElementById('btnShowcaseList');
  const btnShowcaseRotate = document.getElementById('btnShowcaseRotate');
  const viewList = document.getElementById('viewList');
  const viewRotate = document.getElementById('viewRotate');

  if (btnShowcaseList && btnShowcaseRotate && viewList && viewRotate) {
    btnShowcaseList.addEventListener('click', () => {
      btnShowcaseList.classList.add('active');
      btnShowcaseRotate.classList.remove('active');
      viewList.classList.add('active');
      viewRotate.classList.remove('active');
    });

    btnShowcaseRotate.addEventListener('click', () => {
      btnShowcaseRotate.classList.add('active');
      btnShowcaseList.classList.remove('active');
      viewRotate.classList.add('active');
      viewList.classList.remove('active');
      playRotateAnimation();
    });
  }

  // Toggle Standard vs Claude Table
  const toggleStandard = document.getElementById('toggleStandardView');
  const toggleClaude = document.getElementById('toggleClaudeView');
  const standardTable = document.getElementById('standardTable');
  const claudeTable = document.getElementById('claudeTable');
  const displayedListCmd = document.getElementById('displayedListCmd');

  if (toggleStandard && toggleClaude && standardTable && claudeTable && displayedListCmd) {
    toggleStandard.addEventListener('click', () => {
      toggleStandard.classList.add('active');
      toggleClaude.classList.remove('active');
      standardTable.style.display = 'block';
      claudeTable.style.display = 'none';
      displayedListCmd.textContent = 'agyr list';
    });

    toggleClaude.addEventListener('click', () => {
      toggleClaude.classList.add('active');
      toggleStandard.classList.remove('active');
      standardTable.style.display = 'none';
      claudeTable.style.display = 'block';
      displayedListCmd.textContent = 'agyr list --claude';
    });
  }
}

/* ==========================================================================
   4. Auto-Rotate 429 Failover Step Animation
   ========================================================================== */

let rotateAnimTimer = null;

function playRotateAnimation() {
  const container = document.getElementById('terminalRotateScreen');
  if (!container) return;

  const steps = container.querySelectorAll('.anim-step');
  if (!steps.length) return;

  // Clear running timers
  if (rotateAnimTimer) clearTimeout(rotateAnimTimer);

  // Reset steps
  steps.forEach(step => step.classList.remove('visible'));

  const delays = [300, 1000, 1800, 2600, 3400, 4200, 4800];

  delays.forEach((delay, idx) => {
    if (steps[idx]) {
      setTimeout(() => {
        steps[idx].classList.add('visible');
      }, delay);
    }
  });
}

function initRotateAnimation() {
  const replayBtn = document.getElementById('btnReplayRotate');
  if (replayBtn) {
    replayBtn.addEventListener('click', playRotateAnimation);
  }
}

/* ==========================================================================
   5. CLI Command Reference Filters & Live Search
   ========================================================================== */

function initCommandFilters() {
  const filterBtns = document.querySelectorAll('.filter-btn');
  const searchInput = document.getElementById('cmdSearchInput');
  const cmdCards = document.querySelectorAll('.cmd-card');
  const commandsGrid = document.getElementById('commandsGrid');

  let activeCategory = 'all';
  let searchQuery = '';

  const applyFilters = () => {
    let visibleCount = 0;

    cmdCards.forEach(card => {
      const category = card.getAttribute('data-category') || '';
      const text = card.textContent.toLowerCase();

      const matchesCat = (activeCategory === 'all') || category.includes(activeCategory);
      const matchesSearch = (!searchQuery) || text.includes(searchQuery);

      if (matchesCat && matchesSearch) {
        card.style.display = 'flex';
        visibleCount++;
      } else {
        card.style.display = 'none';
      }
    });

    // Check if empty message exists
    let emptyMsg = document.getElementById('cmdEmptyMsg');
    if (visibleCount === 0) {
      if (!emptyMsg) {
        emptyMsg = document.createElement('div');
        emptyMsg.id = 'cmdEmptyMsg';
        emptyMsg.style.gridColumn = '1 / -1';
        emptyMsg.style.textAlign = 'center';
        emptyMsg.style.padding = '3rem 1rem';
        emptyMsg.style.color = 'var(--text-dim)';
        emptyMsg.innerHTML = '<p style="font-size: 1.1rem; margin-bottom: 0.5rem;">No commands match your query.</p><p style="font-size: 0.85rem;">Try searching for "claude", "rotate", or "swapui".</p>';
        commandsGrid.appendChild(emptyMsg);
      }
      emptyMsg.style.display = 'block';
    } else if (emptyMsg) {
      emptyMsg.style.display = 'none';
    }
  };

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeCategory = btn.getAttribute('data-filter');
      applyFilters();
    });
  });

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value.trim().toLowerCase();
      applyFilters();
    });
  }
}

/* ==========================================================================
   6. Navigation, Active Links & Sticky Header
   ========================================================================== */

function initNavigation() {
  const navbar = document.querySelector('.navbar');
  const mobileToggle = document.getElementById('mobileToggle');
  const navMenu = document.getElementById('navMenu');
  const navLinks = document.querySelectorAll('.nav-link');

  // Sticky header background
  window.addEventListener('scroll', () => {
    if (window.scrollY > 30) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // Mobile menu toggle
  if (mobileToggle && navMenu) {
    mobileToggle.addEventListener('click', () => {
      navMenu.classList.toggle('open');
      const isOpen = navMenu.classList.contains('open');
      mobileToggle.setAttribute('aria-expanded', isOpen);
    });

    // Close mobile menu on link click
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('open');
        mobileToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  // Active section indicator using IntersectionObserver
  const sections = document.querySelectorAll('section[id]');
  if ('IntersectionObserver' in window && sections.length) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute('id');
          navLinks.forEach(link => {
            const href = link.getAttribute('href');
            if (href === `#${id}`) {
              link.classList.add('active');
            } else {
              link.classList.remove('active');
            }
          });
        }
      });
    }, {
      rootMargin: '-20% 0px -70% 0px'
    });

    sections.forEach(section => observer.observe(section));
  }
}
