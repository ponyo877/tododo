/**
 * カット割り。撮影テイク（public/captures/<take>/sim.mp4, 30fps）の「動画秒」で区間を指定し、
 * 再生速度と重ねるテロップを決める。数値はテイクごとにフレーム確認で較正する。
 */
export type Segment = {
  id: string;
  /** 素材の開始・終了（動画秒） */
  src: [number, number];
  /** 再生速度（操作区間は速める） */
  speed: number;
  caption?: { text: string; sub?: string; top?: number };
  /** 効果音（区間の先頭からの秒） */
  sfx?: { file: 'sfx-tap' | 'sfx-pop' | 'sfx-tada'; at: number }[];
};

export const FPS = 30;

/** s3 テイク（2026-09-04）。動画秒≒壁時計（±0.3s）。キーボード出現 26.0s、ソート結果 65.0s */
export const SEGMENTS: Segment[] = [
  { id: 'intro', src: [24.0, 26.2], speed: 1, caption: { text: '開いた瞬間、もう入力できる', top: 0.74 } },
  { id: 'add3', src: [26.2, 31.2], speed: 1.4, caption: { text: 'Returnで、次々に', top: 0.46 }, sfx: [{ file: 'sfx-tap', at: 0.3 }, { file: 'sfx-tap', at: 1.7 }, { file: 'sfx-tap', at: 3.1 }] },
  { id: 'others', src: [32.4, 39.0], speed: 1.5, caption: { text: '今日・明日・いつか', sub: '区分は、それだけ', top: 0.45 }, sfx: [{ file: 'sfx-tap', at: 1.8 }, { file: 'sfx-tap', at: 4.0 }] },
  { id: 'swipe', src: [41.0, 45.2], speed: 1.2, caption: { text: '右スワイプで、完了', top: 0.62 }, sfx: [{ file: 'sfx-pop', at: 2.4 }] },
  { id: 'drag', src: [45.2, 49.5], speed: 1, caption: { text: '並び順が、そのまま実行順', sub: '見出しを越えれば区分が変わる', top: 0.62 }, sfx: [{ file: 'sfx-pop', at: 2.4 }] },
  { id: 'add2', src: [50.8, 55.0], speed: 1.7, caption: { text: '雑に放り込んで', top: 0.63 }, sfx: [{ file: 'sfx-tap', at: 1.06 }, { file: 'sfx-tap', at: 2.06 }] },
  { id: 'sortTap', src: [57.6, 59.9], speed: 1, caption: { text: '✨ AIが実行順を提案', top: 0.62 }, sfx: [{ file: 'sfx-tap', at: 0.4 }] },
  { id: 'sorted', src: [64.4, 68.0], speed: 1, caption: { text: '手直しすれば、あなたの順序を学ぶ', sub: 'すべて端末の中で', top: 0.62 }, sfx: [{ file: 'sfx-tada', at: 0.6 }] },
];

export const segmentFrames = (s: Segment) => Math.round(((s.src[1] - s.src[0]) / s.speed) * FPS);

export const totalFrames = (segments: Segment[]) => segments.reduce((n, s) => n + segmentFrames(s), 0);

/** 各区間の開始フレーム（累積） */
export const segmentStarts = (segments: Segment[]) => {
  let at = 0;
  return segments.map((s) => {
    const from = at;
    at += segmentFrames(s);
    return { seg: s, from, duration: segmentFrames(s) };
  });
};
