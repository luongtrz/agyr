import SectionHeading from './SectionHeading';
import Reveal from './Reveal';
import { InlineCode } from './features/InlineCode';
import { ComparisonTable } from './features/ComparisonTable';
import { AmbientGlow } from './features/AmbientGlow';

export default function Comparison() {
  return (
    <section id="comparison" className="relative py-20 md:py-28 overflow-hidden">
      {/* Top subtle gradient divider */}
      <div className="absolute top-0 inset-x-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

      {/* Ambient background glow orb (ported from legacy/fx/visuals.js) */}
      <AmbientGlow color="cyan" top="25%" left="10%" />

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <Reveal>
          <SectionHeading
            eyebrow="Deep-Dive Comparison"
            title="Native CLI Swapper vs Proxy Routers"
            subtitle={
              <>
                Why proxy architectures (like <InlineCode>9router</InlineCode> or mitm daemons) put
                your Google accounts at risk, and how <InlineCode>agyr</InlineCode> solves rotation
                cleanly.
              </>
            }
          />
        </Reveal>

        <Reveal delay={120}>
          <ComparisonTable />
        </Reveal>
      </div>
    </section>
  );
}
