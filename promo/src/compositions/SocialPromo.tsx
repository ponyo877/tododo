import { Audio } from '@remotion/media';
import { AbsoluteFill, Sequence, interpolate, staticFile } from 'remotion';
import { Caption } from '../components/Caption';
import { EndCard, HookCard } from '../components/Cards';
import { PhoneClip } from '../components/PhoneClip';
import { FPS, SEGMENTS, segmentStarts, totalFrames } from '../lib/beats';
import { C, CLIP } from '../lib/theme';

export type SocialProps = { take: string; audio: boolean };

export const HOOK = 75;
export const END = 90;

/** SNS 縦動画（1080×1920）。フック → 端末映像（角丸・影）にテロップ → エンドカード。 */
export const SocialPromo: React.FC<SocialProps> = ({ take, audio }) => {
  const W = 1080;
  const H = 1920;
  const phoneH = 1500;
  const phoneW = Math.round((phoneH * CLIP.width) / CLIP.height);
  const body = totalFrames(SEGMENTS);
  const total = HOOK + body + END;
  return (
    <AbsoluteFill style={{ background: C.cream }}>
      <Sequence name="hook" from={0} durationInFrames={HOOK}>
        <HookCard />
      </Sequence>
      {segmentStarts(SEGMENTS).map(({ seg, from, duration }) => (
        <Sequence key={seg.id} name={seg.id} from={HOOK + from} durationInFrames={duration} premountFor={15}>
          <div style={{ position: 'absolute', left: Math.round((W - phoneW) / 2), top: Math.round((H - phoneH) / 2) - 40, boxShadow: '0 30px 80px rgba(0,0,0,0.22)', borderRadius: 64 }}>
            <PhoneClip take={take} seg={seg} width={phoneW} height={phoneH} radius={64} />
          </div>
          {seg.caption ? <Caption text={seg.caption.text} sub={seg.caption.sub} top={0.83} width={W} height={H} size={60} /> : null}
          {audio
            ? (seg.sfx ?? []).map((s, i) => (
                <Sequence key={i} from={Math.round(s.at * FPS)}>
                  <Audio src={staticFile(`audio/${s.file}.mp3`)} volume={0.5} />
                </Sequence>
              ))
            : null}
        </Sequence>
      ))}
      <Sequence name="end" from={HOOK + body} durationInFrames={END}>
        <EndCard />
      </Sequence>
      {audio ? (
        <Audio
          src={staticFile('audio/bgm.mp3')}
          volume={(f) => interpolate(f, [0, 20, total - 50, total - 2], [0, 0.35, 0.35, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })}
        />
      ) : null}
    </AbsoluteFill>
  );
};
