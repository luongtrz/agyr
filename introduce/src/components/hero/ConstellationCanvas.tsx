import { useEffect, useRef } from 'react';

interface AccountNode {
  label: string;
  status: 'active' | 'ready' | 'cooldown';
  color: string;
  baseX: number;
  baseY: number;
  x: number;
  y: number;
  radius: number;
  pulse: number;
  pulseSpeed: number;
  vx: number;
  vy: number;
}

interface BackgroundParticle {
  x: number;
  y: number;
  radius: number;
  vx: number;
  vy: number;
  alpha: number;
}

interface Packet {
  fromIndex: number;
  toIndex: number;
  progress: number;
  speed: number;
  size: number;
  trail: { x: number; y: number }[];
}

interface Shockwave {
  x: number;
  y: number;
  radius: number;
  maxRadius: number;
  r: number;
  g: number;
  b: number;
  alpha: number;
}

export default function ConstellationCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const prefersReducedMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    let width = 0;
    let height = 0;
    let dpr = 1;
    let isVisible = true;
    let animId: number | null = null;
    let activeSlotIndex = 0;
    let lastFailoverTime = Date.now();

    const mouse = { x: -1000, y: -1000, targetX: -1000, targetY: -1000 };

    let accountNodes: AccountNode[] = [];
    let backgroundParticles: BackgroundParticle[] = [];
    let packets: Packet[] = [];
    let shockwaves: Shockwave[] = [];

    const slotConfigs = [
      { label: 'Slot #1', status: 'active' as const, color: '#22c55e', rx: 0.12, ry: 0.22 },
      { label: 'Slot #2', status: 'ready' as const, color: '#38bdf8', rx: 0.28, ry: 0.11 },
      { label: 'Slot #3', status: 'ready' as const, color: '#38bdf8', rx: 0.72, ry: 0.11 },
      { label: 'Slot #4', status: 'cooldown' as const, color: '#f59e0b', rx: 0.88, ry: 0.22 },
      { label: 'Slot #5', status: 'ready' as const, color: '#c084fc', rx: 0.50, ry: 0.06 },
    ];

    const initNodes = () => {
      accountNodes = slotConfigs.map((cfg, idx) => ({
        label: cfg.label,
        status: cfg.status,
        color: cfg.color,
        baseX: width * cfg.rx,
        baseY: height * cfg.ry,
        x: width * cfg.rx,
        y: height * cfg.ry,
        radius: idx === activeSlotIndex ? 9 : 6.5,
        pulse: 0,
        pulseSpeed: 0.04 + idx * 0.01,
        vx: (Math.random() - 0.5) * 0.2,
        vy: (Math.random() - 0.5) * 0.2,
      }));

      const particleCount = width < 600 ? 12 : 22;
      backgroundParticles = [];
      for (let i = 0; i < particleCount; i++) {
        backgroundParticles.push({
          x: Math.random() * width,
          y: Math.random() * height,
          radius: Math.random() * 1.6 + 0.6,
          vx: (Math.random() - 0.5) * 0.25,
          vy: (Math.random() - 0.5) * 0.25,
          alpha: Math.random() * 0.35 + 0.15,
        });
      }

      packets = [];
      shockwaves = [];
    };

    const drawStatic = () => {
      ctx.clearRect(0, 0, width, height);

      // Faint lines
      for (let i = 0; i < accountNodes.length; i++) {
        for (let j = i + 1; j < accountNodes.length; j++) {
          const a = accountNodes[i];
          const b = accountNodes[j];
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = 'rgba(56, 189, 248, 0.1)';
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }

      // Nodes
      accountNodes.forEach((node) => {
        ctx.beginPath();
        ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
        ctx.fillStyle = node.color;
        ctx.fill();

        ctx.font = '10px ui-monospace, SFMono-Regular, Menlo, monospace';
        ctx.fillStyle = 'rgba(203, 213, 225, 0.45)';
        ctx.textAlign = 'center';
        ctx.fillText(node.label, node.x, node.y + node.radius + 14);
      });
    };

    const triggerAccountFailover = () => {
      if (accountNodes.length < 2) return;

      const fromNode = accountNodes[activeSlotIndex];
      const nextIndex = (activeSlotIndex + 1) % accountNodes.length;

      fromNode.status = 'cooldown';
      fromNode.color = '#f59e0b';

      shockwaves.push({
        x: fromNode.x,
        y: fromNode.y,
        radius: fromNode.radius,
        maxRadius: 40,
        r: 239,
        g: 68,
        b: 68,
        alpha: 0.75,
      });

      packets.push({
        fromIndex: activeSlotIndex,
        toIndex: nextIndex,
        progress: 0,
        speed: 0.022,
        size: 3.5,
        trail: [],
      });
    };

    const handlePacketComplete = (pkt: Packet) => {
      const toNode = accountNodes[pkt.toIndex];
      if (!toNode) return;

      toNode.status = 'active';
      toNode.color = '#22c55e';
      activeSlotIndex = pkt.toIndex;

      shockwaves.push({
        x: toNode.x,
        y: toNode.y,
        radius: toNode.radius,
        maxRadius: 50,
        r: 34,
        g: 197,
        b: 94,
        alpha: 0.85,
      });

      accountNodes.forEach((node, idx) => {
        if (idx !== activeSlotIndex && idx !== pkt.fromIndex) {
          if (node.status === 'cooldown') {
            node.status = 'ready';
            node.color = idx === 4 ? '#c084fc' : '#38bdf8';
          }
        }
      });
    };

    const render = () => {
      if (!isVisible) return;

      ctx.clearRect(0, 0, width, height);

      // Mouse lerp
      mouse.x += (mouse.targetX - mouse.x) * 0.08;
      mouse.y += (mouse.targetY - mouse.y) * 0.08;

      const now = Date.now();
      if (now - lastFailoverTime > 4200) {
        triggerAccountFailover();
        lastFailoverTime = now;
      }

      // Background particles
      backgroundParticles.forEach((p) => {
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

      // Update nodes
      accountNodes.forEach((node) => {
        node.pulse += node.pulseSpeed;
        node.x += node.vx;
        node.y += node.vy;

        const dx = node.x - node.baseX;
        const dy = node.y - node.baseY;
        if (Math.sqrt(dx * dx + dy * dy) > 22) {
          node.vx *= -1;
          node.vy *= -1;
        }

        // Mouse repulsion
        const mdx = node.x - mouse.x;
        const mdy = node.y - mouse.y;
        const mdist = Math.sqrt(mdx * mdx + mdy * mdy);
        if (mdist < 120 && mdist > 0) {
          const force = ((120 - mdist) / 120) * 1.5;
          node.x += (mdx / mdist) * force;
          node.y += (mdy / mdist) * force;
        }
      });

      // Constellation lines
      for (let i = 0; i < accountNodes.length; i++) {
        for (let j = i + 1; j < accountNodes.length; j++) {
          const a = accountNodes[i];
          const b = accountNodes[j];
          const dist = Math.hypot(a.x - b.x, a.y - b.y);
          const alpha = Math.max(0.04, 0.22 - dist / (width * 0.9));

          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = `rgba(56, 189, 248, ${alpha})`;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }

      // Packets
      for (let i = packets.length - 1; i >= 0; i--) {
        const pkt = packets[i];
        pkt.progress += pkt.speed;

        if (pkt.progress >= 1) {
          handlePacketComplete(pkt);
          packets.splice(i, 1);
          continue;
        }

        const from = accountNodes[pkt.fromIndex];
        const to = accountNodes[pkt.toIndex];
        if (!from || !to) continue;

        const currX = from.x + (to.x - from.x) * pkt.progress;
        const currY = from.y + (to.y - from.y) * pkt.progress;

        pkt.trail.push({ x: currX, y: currY });
        if (pkt.trail.length > 7) pkt.trail.shift();

        // Trail
        ctx.beginPath();
        for (let t = 0; t < pkt.trail.length; t++) {
          const tp = pkt.trail[t];
          if (t === 0) ctx.moveTo(tp.x, tp.y);
          else ctx.lineTo(tp.x, tp.y);
        }
        ctx.strokeStyle = 'rgba(34, 197, 94, 0.35)';
        ctx.lineWidth = 2;
        ctx.stroke();

        // Head
        ctx.beginPath();
        ctx.arc(currX, currY, pkt.size, 0, Math.PI * 2);
        ctx.fillStyle = '#ffffff';
        ctx.shadowColor = '#22c55e';
        ctx.shadowBlur = 10;
        ctx.fill();
        ctx.shadowBlur = 0;
      }

      // Shockwaves
      for (let i = shockwaves.length - 1; i >= 0; i--) {
        const sw = shockwaves[i];
        sw.radius += 1.3;
        sw.alpha -= 0.024;

        if (sw.alpha <= 0 || sw.radius >= sw.maxRadius) {
          shockwaves.splice(i, 1);
          continue;
        }

        ctx.beginPath();
        ctx.arc(sw.x, sw.y, sw.radius, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(${sw.r}, ${sw.g}, ${sw.b}, ${sw.alpha})`;
        ctx.lineWidth = 1.6;
        ctx.stroke();
      }

      // Nodes
      accountNodes.forEach((node, idx) => {
        const isActive = idx === activeSlotIndex;
        const pulseScale = 1 + Math.sin(node.pulse) * 0.14;
        const radius = (isActive ? 8.5 : 6) * pulseScale;

        // Outer glow
        const glowRadius = radius * 2.6;
        const gradient = ctx.createRadialGradient(
          node.x,
          node.y,
          0,
          node.x,
          node.y,
          glowRadius
        );
        const rgb =
          node.color === '#22c55e'
            ? '34, 197, 94'
            : node.color === '#38bdf8'
              ? '56, 189, 248'
              : node.color === '#f59e0b'
                ? '245, 158, 11'
                : '192, 132, 252';

        gradient.addColorStop(0, `rgba(${rgb}, 0.35)`);
        gradient.addColorStop(1, `rgba(${rgb}, 0)`);

        ctx.beginPath();
        ctx.arc(node.x, node.y, glowRadius, 0, Math.PI * 2);
        ctx.fillStyle = gradient;
        ctx.fill();

        // Solid core
        ctx.beginPath();
        ctx.arc(node.x, node.y, radius, 0, Math.PI * 2);
        ctx.fillStyle = node.color;
        ctx.fill();

        // White glimmer
        ctx.beginPath();
        ctx.arc(node.x - radius * 0.3, node.y - radius * 0.3, radius * 0.32, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.fill();

        // Node Label (dim so it doesn't distract)
        ctx.font = '10px ui-monospace, SFMono-Regular, Menlo, monospace';
        ctx.textAlign = 'center';
        ctx.fillStyle = isActive ? '#4ade80' : 'rgba(203, 213, 225, 0.45)';
        ctx.fillText(node.label, node.x, node.y + radius + 14);

        if (isActive) {
          ctx.font = '9px ui-monospace, SFMono-Regular, Menlo, monospace';
          ctx.fillStyle = '#22c55e';
          ctx.fillText('● ACTIVE', node.x, node.y + radius + 25);
        } else if (node.status === 'cooldown') {
          ctx.font = '9px ui-monospace, SFMono-Regular, Menlo, monospace';
          ctx.fillStyle = '#f59e0b';
          ctx.fillText('COOLING', node.x, node.y + radius + 25);
        }
      });

      animId = requestAnimationFrame(render);
    };

    const handleResize = () => {
      const rect = canvas.getBoundingClientRect();
      width = Math.max(320, rect.width);
      height = Math.max(300, rect.height);
      dpr = Math.min(window.devicePixelRatio || 1, 2);

      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      initNodes();

      if (prefersReducedMotion) {
        drawStatic();
      }
    };

    const parentSection = canvas.closest('section') || canvas.parentElement;

    const onMouseMove = (e: MouseEvent) => {
      if (!parentSection) return;
      const rect = parentSection.getBoundingClientRect();
      mouse.targetX = e.clientX - rect.left;
      mouse.targetY = e.clientY - rect.top;
    };

    const onMouseLeave = () => {
      mouse.targetX = -1000;
      mouse.targetY = -1000;
    };

    if (parentSection) {
      parentSection.addEventListener('mousemove', onMouseMove, { passive: true });
      parentSection.addEventListener('mouseleave', onMouseLeave, { passive: true });
    }

    handleResize();

    let resizeTimer: ReturnType<typeof setTimeout> | null = null;
    const debouncedResize = () => {
      if (resizeTimer) clearTimeout(resizeTimer);
      resizeTimer = setTimeout(handleResize, 150);
    };
    window.addEventListener('resize', debouncedResize, { passive: true });

    let observer: IntersectionObserver | null = null;
    const onVisibilityChange = () => {
      if (document.hidden) {
        isVisible = false;
        if (animId) cancelAnimationFrame(animId);
      } else {
        isVisible = true;
        lastFailoverTime = Date.now();
        if (!prefersReducedMotion) {
          animId = requestAnimationFrame(render);
        }
      }
    };

    if (!prefersReducedMotion) {
      animId = requestAnimationFrame(render);

      if (typeof IntersectionObserver !== 'undefined' && parentSection) {
        observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                if (!isVisible) {
                  isVisible = true;
                  lastFailoverTime = Date.now();
                  animId = requestAnimationFrame(render);
                }
              } else {
                isVisible = false;
                if (animId) cancelAnimationFrame(animId);
              }
            });
          },
          { threshold: 0.05 }
        );
        observer.observe(parentSection);
      }

      document.addEventListener('visibilitychange', onVisibilityChange);
    }

    return () => {
      if (animId) cancelAnimationFrame(animId);
      if (resizeTimer) clearTimeout(resizeTimer);
      window.removeEventListener('resize', debouncedResize);
      if (parentSection) {
        parentSection.removeEventListener('mousemove', onMouseMove);
        parentSection.removeEventListener('mouseleave', onMouseLeave);
      }
      if (observer) observer.disconnect();
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="hero-canvas pointer-events-none absolute inset-0 z-0 h-full w-full"
      aria-hidden="true"
    />
  );
}
