import { comparisonRows } from './data';
import { StatusBadge } from './StatusBadge';
import './features.css';

export function ComparisonTable() {
  return (
    <div>
      {/* ====================================================================
          Desktop Table View (≥768px)
          Features sticky header visual weight & highlighted recommended column
          ==================================================================== */}
      <div className="hidden md:block">
        <div className="overflow-x-auto rounded-2xl border border-white/10 bg-surface/80 backdrop-blur-md shadow-2xl">
          <table className="w-full text-left border-collapse text-sm">
            <thead>
              <tr className="border-b border-white/10">
                {/* Criteria Column Header */}
                <th
                  scope="col"
                  className="w-[28%] p-5 lg:p-6 font-bold text-ink bg-slate-900/60 align-bottom"
                >
                  <span className="text-sm lg:text-base">Evaluation Criteria</span>
                </th>

                {/* agyr Column Header (Recommended & Highlighted) */}
                <th
                  scope="col"
                  className="w-[38%] p-5 lg:p-6 font-bold text-ink comparison-agyr-header border-l-2 border-r-2 border-emerald/50 align-bottom"
                >
                  <div className="flex flex-col gap-2 items-start">
                    <span className="comparison-brand-pill inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase tracking-wider bg-gradient-to-r from-emerald/30 to-cyan/25 text-emerald border border-emerald/60">
                      <svg
                        className="w-3 h-3 text-emerald"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                      >
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                      Recommended
                    </span>
                    <div className="text-base lg:text-lg text-ink leading-tight">
                      <strong className="text-emerald font-bold">agyr</strong>{' '}
                      <span className="text-slate-300 font-normal text-xs lg:text-sm">
                        (Native CLI Swapper)
                      </span>
                    </div>
                  </div>
                </th>

                {/* Proxy Routers Column Header */}
                <th
                  scope="col"
                  className="w-[34%] p-5 lg:p-6 font-bold text-slate-300 bg-slate-900/60 align-bottom"
                >
                  <div className="text-base lg:text-lg text-slate-300 leading-tight">
                    <strong className="text-ink">Proxy Routers</strong>{' '}
                    <span className="text-muted font-normal text-xs lg:text-sm">
                      (e.g. 9router)
                    </span>
                  </div>
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {comparisonRows.map((row, index) => {
                const isLast = index === comparisonRows.length - 1;
                return (
                  <tr key={row.id} className="hover:bg-white/[0.02] transition-colors">
                    {/* Criterion Title & Subtitle */}
                    <th scope="row" className="p-5 lg:p-6 align-top font-normal">
                      <strong className="block text-ink font-semibold text-sm lg:text-base mb-1">
                        {row.title}
                      </strong>
                      <span className="block text-dim text-xs leading-relaxed">
                        {row.subtitle}
                      </span>
                    </th>

                    {/* agyr Data Cell */}
                    <td
                      className={`p-5 lg:p-6 align-top comparison-agyr-cell border-l-2 border-r-2 border-emerald/45 text-slate-100 ${
                        isLast ? 'border-b-2 border-emerald/45' : ''
                      }`}
                    >
                      <StatusBadge variant={row.agyr.badgeVariant} text={row.agyr.badgeText} />
                      <p className="text-xs lg:text-[0.92rem] text-slate-200 leading-relaxed mt-1">
                        {row.agyr.description}
                      </p>
                    </td>

                    {/* Proxy Routers Data Cell */}
                    <td className="p-5 lg:p-6 align-top text-muted">
                      <StatusBadge variant={row.proxy.badgeVariant} text={row.proxy.badgeText} />
                      <p className="text-xs lg:text-[0.92rem] text-slate-400 leading-relaxed mt-1">
                        {row.proxy.description}
                      </p>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* ====================================================================
          Mobile Stacked View (<768px)
          Criteria stacked as high-contrast cards to ensure comfortable reading
          at 360px without requiring cramped horizontal scrolling
          ==================================================================== */}
      <div className="block md:hidden space-y-4">
        {comparisonRows.map((row) => (
          <div
            key={row.id}
            className="rounded-2xl border border-white/10 bg-surface/80 backdrop-blur-md p-4 sm:p-5 shadow-lg space-y-3.5"
          >
            {/* Criteria Header */}
            <div>
              <h3 className="text-base font-bold text-ink">{row.title}</h3>
              <p className="text-xs text-dim mt-0.5">{row.subtitle}</p>
            </div>

            {/* agyr (Native CLI Swapper) Subcard */}
            <div className="rounded-xl border border-emerald/45 bg-emerald/5 p-3.5 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-1.5">
                  <span className="font-bold text-sm text-emerald">agyr</span>
                  <span className="text-[11px] text-slate-400">(Native CLI Swapper)</span>
                </div>
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-emerald/20 text-emerald border border-emerald/50">
                  <svg
                    className="w-2.5 h-2.5 text-emerald"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  Recommended
                </span>
              </div>
              <StatusBadge variant={row.agyr.badgeVariant} text={row.agyr.badgeText} />
              <p className="text-xs text-slate-200 leading-relaxed">{row.agyr.description}</p>
            </div>

            {/* Proxy Routers Subcard */}
            <div className="rounded-xl border border-white/10 bg-white/[0.02] p-3.5 space-y-2">
              <div className="flex items-center gap-1.5">
                <span className="font-semibold text-sm text-slate-300">Proxy Routers</span>
                <span className="text-[11px] text-muted">(e.g. 9router)</span>
              </div>
              <StatusBadge variant={row.proxy.badgeVariant} text={row.proxy.badgeText} />
              <p className="text-xs text-slate-400 leading-relaxed">{row.proxy.description}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
