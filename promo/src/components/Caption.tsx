import { Easing, interpolate, useCurrentFrame } from 'remotion';
import { C, FONT } from '../lib/theme';

/**
 * テロップ。墨のスラブに白文字、下から少し浮き上がってフェードイン。
 * top は合成の高さに対する比率（0〜1）。
 */
export const Caption: React.FC<{ text: string; sub?: string; top?: number; width: number; height: number; size?: number; delay?: number }> = ({
  text,
  sub,
  top = 0.6,
  width,
  height,
  size = 56,
  delay = 3,
}) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - delay, [0, 12], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1) });
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        top: Math.round(height * top),
        width,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 14,
        opacity: p,
        translate: `0px ${Math.round((1 - p) * 24)}px`,
      }}
    >
      <div
        style={{
          background: C.ink,
          color: C.paper,
          borderRadius: 999,
          padding: `${Math.round(size * 0.32)}px ${Math.round(size * 0.7)}px ${Math.round(size * 0.38)}px`,
          fontFamily: FONT.sans,
          fontWeight: 900,
          fontSize: size,
          lineHeight: 1.15,
          letterSpacing: 1,
          whiteSpace: 'nowrap',
          boxShadow: '0 12px 40px rgba(0,0,0,0.18)',
        }}
      >
        {text}
      </div>
      {sub ? (
        <div
          style={{
            background: C.paper,
            color: C.ink,
            borderRadius: 999,
            padding: `${Math.round(size * 0.22)}px ${Math.round(size * 0.55)}px ${Math.round(size * 0.26)}px`,
            fontFamily: FONT.sans,
            fontWeight: 700,
            fontSize: Math.round(size * 0.72),
            whiteSpace: 'nowrap',
            boxShadow: '0 8px 30px rgba(0,0,0,0.14)',
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};
