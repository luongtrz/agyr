import { useEffect, useState, useRef, useCallback } from 'react';

export interface UseTypewriterOptions {
  start?: boolean;
  speed?: number;
  onComplete?: () => void;
}

export interface UseTypewriterReturn {
  displayedText: string;
  isComplete: boolean;
  isTyping: boolean;
  reset: () => void;
}

/**
 * Types out `text` character-by-character at the given `speed`.
 * Cleans up all pending timers on unmount or argument changes.
 * Immediately displays full text when `prefers-reduced-motion` is active.
 */
export function useTypewriter(
  text: string,
  options: UseTypewriterOptions = {},
): UseTypewriterReturn {
  const { start = true, speed = 25, onComplete } = options;
  const [displayedText, setDisplayedText] = useState('');
  const [isComplete, setIsComplete] = useState(false);
  const [isTyping, setIsTyping] = useState(false);

  const onCompleteRef = useRef(onComplete);
  onCompleteRef.current = onComplete;

  const reset = useCallback(() => {
    setDisplayedText('');
    setIsComplete(false);
    setIsTyping(false);
  }, []);

  useEffect(() => {
    if (!start) {
      setDisplayedText('');
      setIsComplete(false);
      setIsTyping(false);
      return;
    }

    if (text.length === 0) {
      setDisplayedText('');
      setIsComplete(true);
      setIsTyping(false);
      onCompleteRef.current?.();
      return;
    }

    const isReduced =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (isReduced) {
      setDisplayedText(text);
      setIsComplete(true);
      setIsTyping(false);
      onCompleteRef.current?.();
      return;
    }

    setDisplayedText('');
    setIsComplete(false);
    setIsTyping(true);

    let currentIndex = 0;
    let timerId: ReturnType<typeof setTimeout> | null = null;

    const tick = () => {
      currentIndex += 1;
      setDisplayedText(text.slice(0, currentIndex));

      if (currentIndex < text.length) {
        timerId = setTimeout(tick, speed);
      } else {
        setIsTyping(false);
        setIsComplete(true);
        onCompleteRef.current?.();
      }
    };

    timerId = setTimeout(tick, speed);

    return () => {
      if (timerId !== null) {
        clearTimeout(timerId);
      }
    };
  }, [text, start, speed]);

  return { displayedText, isComplete, isTyping, reset };
}
