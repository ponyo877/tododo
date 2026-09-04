import { OffthreadVideo, staticFile } from 'remotion';
import { FPS, type Segment } from '../lib/beats';

/** 撮影素材の一区間を、指定サイズに高さ基準でフィットさせて再生する。 */
export const PhoneClip: React.FC<{ take: string; seg: Segment; width: number; height: number; radius?: number }> = ({
  take,
  seg,
  width,
  height,
  radius = 0,
}) => (
  <div style={{ width, height, overflow: 'hidden', borderRadius: radius, background: '#fff' }}>
    <OffthreadVideo
      src={staticFile(`captures/${take}/sim.mp4`)}
      startFrom={Math.round(seg.src[0] * FPS)}
      endAt={Math.round(seg.src[1] * FPS)}
      playbackRate={seg.speed}
      muted
      style={{ width, height, objectFit: 'cover' }}
    />
  </div>
);
