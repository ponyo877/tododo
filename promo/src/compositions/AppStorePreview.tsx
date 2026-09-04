import { Audio } from '@remotion/media';
import { AbsoluteFill, Sequence, interpolate, staticFile } from 'remotion';
import { Caption } from '../components/Caption';
import { PhoneClip } from '../components/PhoneClip';
import { FPS, SEGMENTS, segmentStarts, totalFrames } from '../lib/beats';
import { C, CLIP } from '../lib/theme';

export type AppStoreProps = { take: string; audio: boolean };

/**
 * App Store プレビュー（886×1920）。実機映像を全面に、控えめなテロップだけ重ねる。
 * 端末フレーム・手・エンドカード・バッジ・URL は入れない（審査ガイドライン）。
 */
export const AppStorePreview: React.FC<AppStoreProps> = ({ take, audio }) => {
  const W = 886;
  const H = 1920;
  const clipW = Math.round((H * CLIP.width) / CLIP.height) + 2;
  const total = totalFrames(SEGMENTS);
  return (
    <AbsoluteFill style={{ background: C.paper }}>
      {segmentStarts(SEGMENTS).map(({ seg, from, duration }) => (
        <Sequence key={seg.id} name={seg.id} from={from} durationInFrames={duration} premountFor={15}>
          <div style={{ position: 'absolute', left: Math.round((W - clipW) / 2), top: 0 }}>
            <PhoneClip take={take} seg={seg} width={clipW} height={H} />
          </div>
          {seg.caption ? <Caption text={seg.caption.text} sub={seg.caption.sub} top={seg.caption.top} width={W} height={H} size={46} /> : null}
          {audio
            ? (seg.sfx ?? []).map((s, i) => (
                <Sequence key={i} from={Math.round(s.at * FPS)}>
                  <Audio src={staticFile(`audio/${s.file}.mp3`)} volume={0.5} />
                </Sequence>
              ))
            : null}
        </Sequence>
      ))}
      {audio ? (
        <Audio
          src={staticFile('audio/bgm.mp3')}
          volume={(f) => interpolate(f, [0, 20, total - 45, total - 2], [0, 0.35, 0.35, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })}
        />
      ) : null}
    </AbsoluteFill>
  );
};
