import { CanvasImage, Easing, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { C, FONT } from '../lib/theme';

/** SNS 用フック。白地に一行、ドードーが横にいる。 */
export const HookCard: React.FC = () => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [0, 14], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1) });
  return (
    <div style={{ position: 'absolute', inset: 0, background: C.paper, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 48 }}>
      <CanvasImage src={staticFile('brand/dodo.svg')} style={{ width: 300, height: 300, opacity: p, scale: String(interpolate(p, [0, 1], [0.8, 1])) }} />
      <div style={{ fontFamily: FONT.sans, fontWeight: 900, fontSize: 84, color: C.ink, textAlign: 'center', lineHeight: 1.35, opacity: p, translate: `0px ${Math.round((1 - p) * 30)}px` }}>
        やることリスト、
        <br />
        開くのに何秒かかる？
      </div>
    </div>
  );
};

/** SNS 用エンドカード。アイコン・名前・一言。 */
export const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [0, 14], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1) });
  return (
    <div style={{ position: 'absolute', inset: 0, background: C.paper, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 36 }}>
      <CanvasImage
        src={staticFile('brand/icon.png')}
        style={{ width: 260, height: 260, borderRadius: 58, boxShadow: '0 20px 60px rgba(0,0,0,0.18)', opacity: p, scale: String(interpolate(p, [0, 1], [0.8, 1])) }}
      />
      <div style={{ fontFamily: FONT.sans, fontWeight: 900, fontSize: 96, color: C.ink, letterSpacing: 2, opacity: p }}>tododo</div>
      <div style={{ fontFamily: FONT.sans, fontWeight: 700, fontSize: 46, color: C.gray, opacity: p, translate: `0px ${Math.round((1 - p) * 20)}px` }}>今日・明日・いつか。それだけ。</div>
      <div style={{ marginTop: 20, fontFamily: FONT.sans, fontWeight: 700, fontSize: 38, color: C.paper, background: C.ink, borderRadius: 999, padding: '18px 44px 22px', opacity: p }}>App Store で近日公開</div>
    </div>
  );
};
