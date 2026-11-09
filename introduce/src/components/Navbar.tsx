import { useEffect, useRef, useState } from 'react';
import { REPO_URL } from '../lib/site';

interface NavItem {
  label: string;
  href: string;
  id: string;
}

const NAV_ITEMS: NavItem[] = [
  { label: 'Features', href: '#features', id: 'features' },
  { label: 'Live Showcase', href: '#demo', id: 'demo' },
  { label: 'Architecture', href: '#comparison', id: 'comparison' },
  { label: 'Quick Start', href: '#quick-start', id: 'quick-start' },
  { label: 'AI Agents', href: '#agent-orchestration', id: 'agent-orchestration' },
  { label: 'CLI Reference', href: '#cli-reference', id: 'cli-reference' },
];

export default function Navbar() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [scrollProgress, setScrollProgress] = useState(0);
  const [activeSection, setActiveSection] = useState<string>('');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const navLinksRef = useRef<HTMLDivElement>(null);
  const linkElementsRef = useRef<Map<string, HTMLAnchorElement>>(new Map());
  const [indicatorStyle, setIndicatorStyle] = useState<{
    left: number;
    width: number;
    opacity: number;
  }>({ left: 0, width: 0, opacity: 0 });

  // Update scroll reading progress and scrolled background
  useEffect(() => {
    const handleScroll = () => {
      const scrollY = window.scrollY;
      setIsScrolled(scrollY > 30);

      const totalScroll = document.documentElement.scrollHeight - window.innerHeight;
      if (totalScroll > 0) {
        const progress = Math.min(Math.max((scrollY / totalScroll) * 100, 0), 100);
        setScrollProgress(progress);
      } else {
        setScrollProgress(0);
      }
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // IntersectionObserver for active section tracking
  useEffect(() => {
    if (typeof IntersectionObserver === 'undefined') return;

    const sectionIds = ['hero', ...NAV_ITEMS.map((item) => item.id)];
    const sectionElements = sectionIds
      .map((id) => document.getElementById(id))
      .filter((el): el is HTMLElement => el !== null);

    if (sectionElements.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const id = entry.target.id;
            setActiveSection(id === 'hero' ? '' : id);
          }
        });
      },
      {
        rootMargin: '-20% 0px -65% 0px',
        threshold: 0.05,
      }
    );

    sectionElements.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);

  // Update sliding nav underline indicator
  useEffect(() => {
    if (!activeSection) {
      setIndicatorStyle((prev) => ({ ...prev, opacity: 0 }));
      return;
    }

    const activeEl = linkElementsRef.current.get(activeSection);
    const containerEl = navLinksRef.current;
    if (activeEl && containerEl) {
      const activeRect = activeEl.getBoundingClientRect();
      const containerRect = containerEl.getBoundingClientRect();
      setIndicatorStyle({
        left: activeRect.left - containerRect.left,
        width: activeRect.width,
        opacity: 1,
      });
    } else {
      setIndicatorStyle((prev) => ({ ...prev, opacity: 0 }));
    }
  }, [activeSection]);

  // Close mobile menu on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setMobileMenuOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleNavLinkHover = (id: string | null) => {
    const targetId = id || activeSection;
    if (!targetId) {
      setIndicatorStyle((prev) => ({ ...prev, opacity: 0 }));
      return;
    }
    const targetEl = linkElementsRef.current.get(targetId);
    const containerEl = navLinksRef.current;
    if (targetEl && containerEl) {
      const targetRect = targetEl.getBoundingClientRect();
      const containerRect = containerEl.getBoundingClientRect();
      setIndicatorStyle({
        left: targetRect.left - containerRect.left,
        width: targetRect.width,
        opacity: 1,
      });
    }
  };

  return (
    <header
      id="top"
      className={`sticky top-0 z-50 w-full transition-all duration-300 ${
        isScrolled
          ? 'border-b border-emerald/20 bg-main/95 shadow-xl shadow-black/60 backdrop-blur-xl'
          : 'border-b border-white/10 bg-main/80 backdrop-blur-xl'
      }`}
    >
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6 lg:px-8">
        {/* Brand Logo & Version Tag */}
        <a
          href="#top"
          aria-label="agyr home"
          className="group flex items-center gap-2.5 text-ink no-underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald rounded-lg"
        >
          <span className="flex h-8 w-8 items-center justify-center rounded-lg border border-emerald/30 bg-emerald/10 text-emerald transition-all duration-200 group-hover:scale-105 group-hover:border-emerald/50 group-hover:shadow-[0_0_14px_rgba(34,197,94,0.35)]">
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <polyline points="4 17 10 11 4 5" />
              <line x1="12" y1="19" x2="20" y2="19" />
              <path d="M19 5a7 7 0 0 1 0 10" stroke="#38bdf8" />
            </svg>
          </span>
          <span className="font-mono text-xl font-extrabold tracking-tight text-white">agyr</span>
          <span className="rounded-full border border-cyan/30 bg-cyan/10 px-2 py-0.5 font-mono text-[10px] font-semibold tracking-wide text-cyan">
            v1.5
          </span>
        </a>

        {/* Desktop Navigation Links with Sliding Underline Indicator */}
        <nav
          ref={navLinksRef}
          aria-label="Primary navigation"
          onMouseLeave={() => handleNavLinkHover(null)}
          className="relative hidden items-center gap-6 lg:flex"
        >
          {NAV_ITEMS.map((item) => {
            const isActive = activeSection === item.id;
            return (
              <a
                key={item.id}
                ref={(el) => {
                  if (el) linkElementsRef.current.set(item.id, el);
                  else linkElementsRef.current.delete(item.id);
                }}
                href={item.href}
                onMouseEnter={() => handleNavLinkHover(item.id)}
                className={`py-1 text-sm font-medium transition-colors duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald rounded ${
                  isActive ? 'text-white font-semibold' : 'text-muted hover:text-white'
                }`}
              >
                {item.label}
              </a>
            );
          })}

          {/* Sliding Underline Accent Indicator */}
          <span
            className="pointer-events-none absolute -bottom-1 h-0.5 rounded-full bg-gradient-to-r from-emerald to-cyan shadow-[0_0_8px_rgba(34,197,94,0.6)] transition-all duration-300 ease-out"
            style={{
              transform: `translateX(${indicatorStyle.left}px)`,
              width: `${indicatorStyle.width}px`,
              opacity: indicatorStyle.opacity,
            }}
            aria-hidden="true"
          />
        </nav>

        {/* Actions: GitHub Star CTA & Mobile Menu Toggle */}
        <div className="flex items-center gap-3">
          <a
            href={REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-3.5 py-1.5 text-xs font-semibold text-ink transition-all duration-200 hover:border-white/25 hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald"
          >
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="currentColor"
              aria-hidden="true"
            >
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
            </svg>
            <span>Star on GitHub</span>
          </a>

          {/* Mobile Hamburger Toggle Button */}
          <button
            type="button"
            onClick={() => setMobileMenuOpen((prev) => !prev)}
            aria-label="Toggle navigation menu"
            aria-expanded={mobileMenuOpen}
            aria-controls="mobile-nav-menu"
            className="flex h-9 w-9 flex-col items-center justify-center gap-1.5 rounded-lg border border-white/10 bg-white/5 text-ink transition hover:border-white/20 hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald lg:hidden"
          >
            <span
              className={`h-0.5 w-5 rounded-full bg-slate-200 transition-transform duration-200 ${
                mobileMenuOpen ? 'translate-y-2 rotate-45' : ''
              }`}
            />
            <span
              className={`h-0.5 w-5 rounded-full bg-slate-200 transition-opacity duration-200 ${
                mobileMenuOpen ? 'opacity-0' : 'opacity-100'
              }`}
            />
            <span
              className={`h-0.5 w-5 rounded-full bg-slate-200 transition-transform duration-200 ${
                mobileMenuOpen ? '-translate-y-2 -rotate-45' : ''
              }`}
            />
          </button>
        </div>
      </div>

      {/* Mobile Menu Dropdown Panel */}
      {mobileMenuOpen && (
        <div
          id="mobile-nav-menu"
          className="border-b border-white/10 bg-surface/95 px-4 pt-3 pb-6 backdrop-blur-2xl lg:hidden"
        >
          <nav className="flex flex-col gap-2" aria-label="Mobile navigation">
            {NAV_ITEMS.map((item) => {
              const isActive = activeSection === item.id;
              return (
                <a
                  key={item.id}
                  href={item.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`rounded-lg px-3 py-2 text-sm font-medium transition ${
                    isActive
                      ? 'border border-emerald/30 bg-emerald/10 text-white font-semibold'
                      : 'text-muted hover:bg-white/5 hover:text-white'
                  }`}
                >
                  {item.label}
                </a>
              );
            })}

            <div className="mt-2 pt-2 border-t border-white/10">
              <a
                href={REPO_URL}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setMobileMenuOpen(false)}
                className="flex items-center justify-center gap-2 rounded-lg border border-white/10 bg-white/5 py-2.5 text-xs font-semibold text-ink transition hover:bg-white/10 hover:text-white"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
                </svg>
                <span>Star on GitHub</span>
              </a>
            </div>
          </nav>
        </div>
      )}

      {/* Thin Gradient Scroll Reading Progress Bar at Bottom of Header */}
      <div
        className="absolute bottom-0 left-0 h-[2px] bg-gradient-to-r from-emerald to-cyan shadow-[0_0_8px_rgba(34,197,94,0.7)] transition-all duration-75"
        style={{ width: `${scrollProgress}%` }}
        aria-hidden="true"
      />
    </header>
  );
}
