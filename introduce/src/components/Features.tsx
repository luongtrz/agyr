import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import { uspItems } from './features/data';
import { UspCard } from './features/UspCard';
import { AmbientGlow } from './features/AmbientGlow';

export default function Features() {
  return (
    <section id="features" className="relative py-20 md:py-28 overflow-hidden">
      {/* Top subtle gradient divider */}
      <div className="absolute top-0 inset-x-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

      {/* Ambient background glow orb (ported from legacy/fx/visuals.js) */}
      <AmbientGlow color="emerald" top="15%" left="85%" />

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Key Advantages"
            title="Why Developers Choose agyr"
            subtitle="Engineered specifically for the official Google Antigravity CLI. No shortcuts, no shady reverse proxies."
          />
        </Reveal>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
          {uspItems.map((item, index) => (
            <Reveal key={item.id} delay={index * 100}>
              <UspCard item={item} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
