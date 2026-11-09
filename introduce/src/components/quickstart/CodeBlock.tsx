import type { ReactNode } from 'react';
import CopyButton from '../CopyButton';
import './quickstart.css';

interface CodeBlockProps {
  /** The code string or ReactNode to display */
  code: string | ReactNode;
  /** Plain-text to copy to clipboard */
  copyText: string;
  /** Terminal title / tab label (e.g. 'bash', defaults to 'bash') */
  label?: string;
  /** Extra CSS classes for outer container */
  className?: string;
  /** Extra CSS classes for pre tag */
  preClassName?: string;
}

/**
 * Highlights shell commands, comments, flags, strings, roles, and paths.
 */
function highlightCodeLine(line: string, lineIndex: number): ReactNode {
  const trimmed = line.trimStart();

  // If the line is entirely a comment
  if (trimmed.startsWith('#')) {
    return (
      <span key={lineIndex} className="text-dim italic whitespace-pre-wrap break-words">
        {line}
      </span>
    );
  }

  // Tokenize line: comments, strings, flags, commands, roles, file paths, models
  const tokenRegex =
    /(#[^\n]*)|("[^"]*"|'[^']*')|(--?[a-zA-Z0-9-]+)|(\b(?:agyr|agy-run|agy-task|agy|curl)\b)|(\b(?:Role|Sub-agent):)|((?:\.[a-zA-Z0-9_./-]+\.(?:txt|md|sh|ts|js))\b)|(\bgemini-[a-zA-Z0-9.-]+\b)/g;

  const elements: ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = tokenRegex.exec(line)) !== null) {
    if (match.index > lastIndex) {
      elements.push(line.slice(lastIndex, match.index));
    }

    const [, comment, str, flag, cmd, role, filePath, modelName] = match;

    if (comment) {
      elements.push(
        <span key={match.index} className="text-dim italic whitespace-pre-wrap break-words">
          {comment}
        </span>,
      );
    } else if (str) {
      elements.push(
        <span key={match.index} className="text-emerald">
          {str}
        </span>,
      );
    } else if (flag) {
      elements.push(
        <span key={match.index} className="text-amber">
          {flag}
        </span>,
      );
    } else if (cmd) {
      elements.push(
        <span key={match.index} className="font-semibold text-cyan">
          {cmd}
        </span>,
      );
    } else if (role) {
      elements.push(
        <span key={match.index} className="font-semibold text-violet">
          {role}
        </span>,
      );
    } else if (filePath) {
      elements.push(
        <span key={match.index} className="text-amber">
          {filePath}
        </span>,
      );
    } else if (modelName) {
      elements.push(
        <span key={match.index} className="text-emerald">
          {modelName}
        </span>,
      );
    }

    lastIndex = tokenRegex.lastIndex;
  }

  if (lastIndex < line.length) {
    elements.push(line.slice(lastIndex));
  }

  return <span key={lineIndex}>{elements}</span>;
}

export default function CodeBlock({
  code,
  copyText,
  label = 'bash',
  className = '',
  preClassName = '',
}: CodeBlockProps) {
  return (
    <div
      className={`relative flex flex-col rounded-xl border border-white/10 bg-terminal shadow-lg overflow-hidden min-h-[240px] lg:min-h-[280px] ${className}`}
    >
      {/* Top action bar / reserved gutter (solves defect d: copy button never overlaps code text) */}
      <div className="flex items-center justify-between border-b border-white/5 bg-terminal-header/80 px-3.5 py-1.5 select-none flex-none">
        <div className="flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full bg-danger/80" aria-hidden="true" />
          <span className="h-2.5 w-2.5 rounded-full bg-amber/80" aria-hidden="true" />
          <span className="h-2.5 w-2.5 rounded-full bg-emerald/80" aria-hidden="true" />
          <span className="ml-2 font-mono text-[11px] font-medium uppercase tracking-wider text-dim">
            {label}
          </span>
        </div>
        <CopyButton text={copyText} className="text-xs" />
      </div>

      {/* Code body with horizontal scroll */}
      <div className="quickstart-code-scroll overflow-hidden p-3.5 flex-1">
        <pre
          className={`font-mono text-xs leading-relaxed text-ink/90 whitespace-pre-wrap break-words break-all w-full ${preClassName}`}
        >
          <code>
            {typeof code === 'string'
              ? code.split('\n').map((line, idx) => {
                  const isComment = line.trimStart().startsWith('#');
                  return (
                    <div
                      key={idx}
                      className={`min-h-[1.25rem] ${
                        isComment ? 'whitespace-pre-wrap break-words' : ''
                      }`}
                    >
                      {highlightCodeLine(line, idx)}
                    </div>
                  );
                })
              : code}
          </code>
        </pre>
      </div>
    </div>
  );
}
