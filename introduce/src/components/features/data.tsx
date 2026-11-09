import { InlineCode } from './InlineCode';
import type { ComparisonRow, UspItem } from './types';

export const uspItems: UspItem[] = [
  {
    id: 'privacy-first',
    badge: {
      label: '100% On-Device',
      icon: (
        <svg
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          aria-hidden="true"
        >
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
      ),
    },
    icon: (
      <svg
        width="28"
        height="28"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        aria-hidden="true"
      >
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
      </svg>
    ),
    title: '100% Local & Privacy-First',
    description: (
      <>
        Your OAuth tokens stay strictly on your local filesystem under strict permissions (
        <InlineCode>chmod 600</InlineCode>) or native Windows Credential Manager. Zero third-party
        telemetry, zero external servers.
      </>
    ),
    points: [
      <>
        Tokens locked in <InlineCode>~/.gemini/antigravity-cli/accounts/</InlineCode>
      </>,
      'Atomic file writes & cross-platform file locking',
      <>
        Windows Credential Manager (<InlineCode>gemini:antigravity</InlineCode>) support
      </>,
    ],
    watermark: (
      <svg
        width="120"
        height="120"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.2"
        aria-hidden="true"
      >
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
      </svg>
    ),
    accentColor: 'emerald',
  },
  {
    id: 'zero-ban-risk',
    badge: {
      label: 'Authentic Fingerprint',
      icon: (
        <svg
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          aria-hidden="true"
        >
          <polyline points="20 6 9 17 4 12" />
        </svg>
      ),
    },
    icon: (
      <svg
        width="28"
        height="28"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        aria-hidden="true"
      >
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      </svg>
    ),
    title: 'Zero-Ban Risk Architecture',
    description: (
      <>
        Unlike reverse-proxy tools that get flagged by Google for datacenter IPs and forged TLS
        signatures, <InlineCode>agyr</InlineCode> directly invokes the official{' '}
        <InlineCode>agy</InlineCode> binary from your machine.
      </>
    ),
    points: [
      'Authentic Google CLI binary & TLS/HTTP2 fingerprints',
      'Clean D-Bus keyring isolation without binary modification',
      'Zero proxy daemons listening on local network ports',
    ],
    watermark: (
      <svg
        width="120"
        height="120"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.2"
        aria-hidden="true"
      >
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      </svg>
    ),
    accentColor: 'cyan',
  },
  {
    id: 'smart-scheduling',
    badge: {
      label: 'Bottleneck Heuristics',
      icon: (
        <svg
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          aria-hidden="true"
        >
          <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
        </svg>
      ),
    },
    icon: (
      <svg
        width="28"
        height="28"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        aria-hidden="true"
      >
        <polyline points="23 4 23 10 17 10" />
        <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
      </svg>
    ),
    title: 'Smart Scheduling & 429 Failover',
    description: (
      <>
        Never waste quota again. <InlineCode>agyr</InlineCode> tracks Google quota windows dynamically,
        selecting replacement accounts based on weekly expiration and bottleneck heuristics.
      </>
    ),
    points: [
      <>
        Bottleneck-aware account sorting (<InlineCode>min(Gemini 5h, Week)</InlineCode>)
      </>,
      'Tie-breaking prioritizing accounts resetting soonest',
      <>
        Flawless <InlineCode>--conversation</InlineCode> context handover
      </>,
    ],
    watermark: (
      <svg
        width="120"
        height="120"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.2"
        aria-hidden="true"
      >
        <polyline points="23 4 23 10 17 10" />
        <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
      </svg>
    ),
    accentColor: 'violet',
  },
];

export const comparisonRows: ComparisonRow[] = [
  {
    id: 'execution-architecture',
    title: 'Execution Architecture',
    subtitle: 'How requests are transmitted to Google',
    agyr: {
      badgeVariant: 'green',
      badgeText: 'Direct Native',
      description: (
        <>
          Direct local CLI execution via official <InlineCode>agy</InlineCode> binary. No proxy
          middleman.
        </>
      ),
    },
    proxy: {
      badgeVariant: 'red',
      badgeText: 'High Complexity',
      description: 'Local/remote reverse HTTP/SOCKS proxy daemon intercepting HTTP traffic.',
    },
  },
  {
    id: 'ban-risk',
    title: 'Account Ban Risk',
    subtitle: 'Google anti-harvesting detection',
    agyr: {
      badgeVariant: 'green',
      badgeText: 'Zero Ban Risk',
      description:
        'Authentic Google CLI binary, real client TLS fingerprints, and genuine residential IP.',
    },
    proxy: {
      badgeVariant: 'red',
      badgeText: 'Severe Ban Risk',
      description:
        'Fake TLS fingerprints, cloud/datacenter IP blacklists, and abnormal API call sequences.',
    },
  },
  {
    id: 'privacy',
    title: 'Credential Privacy',
    subtitle: 'Token storage and handling',
    agyr: {
      badgeVariant: 'green',
      badgeText: '100% Local',
      description: (
        <>
          OAuth tokens remain <InlineCode>chmod 600</InlineCode> on disk or OS Credential Manager.
          Never read or sent anywhere.
        </>
      ),
    },
    proxy: {
      badgeVariant: 'red',
      badgeText: 'Intercepted',
      description:
        'Tokens must be decrypted or stored in proxy daemon memory, vulnerable to leakage.',
    },
  },
  {
    id: 'cli-updates',
    title: 'Antigravity CLI Updates',
    subtitle: 'Google upstream compatibility',
    agyr: {
      badgeVariant: 'green',
      badgeText: 'Instant Compatibility',
      description: (
        <>
          Always 100% compatible with latest <InlineCode>agy</InlineCode> releases immediately upon
          updating.
        </>
      ),
    },
    proxy: {
      badgeVariant: 'amber',
      badgeText: 'Frequently Breaks',
      description:
        'Breaks whenever Google updates backend protobufs, SSE protocols, or header signatures.',
    },
  },
  {
    id: 'failover',
    title: '429 Failover & Session Resume',
    subtitle: 'Context retention during long tasks',
    agyr: {
      badgeVariant: 'green',
      badgeText: 'Native Context Resume',
      description: (
        <>
          Transfers <InlineCode>--conversation &lt;id&gt;</InlineCode> immediately to next account.
          Zero prompt token waste.
        </>
      ),
    },
    proxy: {
      badgeVariant: 'amber',
      badgeText: 'Session Drop',
      description:
        'Often drops TCP connection abruptly or requires full prompt replay from scratch.',
    },
  },
  {
    id: 'resource-overhead',
    title: 'System Resource Overhead',
    subtitle: 'RAM & background CPU footprint',
    agyr: {
      badgeVariant: 'green',
      badgeText: '0 MB RAM',
      description: 'Pure lightweight Bash script. 0 background processes when idle.',
    },
    proxy: {
      badgeVariant: 'dim',
      badgeText: '150–500 MB RAM',
      description: 'Heavy Node.js, Go, or Docker container running 24/7 in background.',
    },
  },
  {
    id: 'os-support',
    title: 'Operating System Support',
    subtitle: 'Cross-platform integration',
    agyr: {
      badgeVariant: 'green',
      badgeText: 'First-Class Native',
      description: (
        <>
          Linux (D-Bus keyring isolation) &amp; Windows (Credential Manager +{' '}
          <InlineCode>.cmd</InlineCode> wrappers).
        </>
      ),
    },
    proxy: {
      badgeVariant: 'dim',
      badgeText: 'Varies',
      description: 'Requires complex loopback adapters, certificates, or Docker networking.',
    },
  },
];
