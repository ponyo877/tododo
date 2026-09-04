import { Composition } from 'remotion';
import { AppStorePreview } from './compositions/AppStorePreview';
import { END, HOOK, SocialPromo } from './compositions/SocialPromo';
import { FPS, SEGMENTS, totalFrames } from './lib/beats';
import { fontsReady } from './lib/fonts';

/** 採用テイク。撮り直したらここを更新する。 */
const TAKE = 's3';

export const Root: React.FC = () => {
  void fontsReady;
  const body = totalFrames(SEGMENTS);
  return (
    <>
      <Composition id="AppStorePreview" component={AppStorePreview} durationInFrames={body} fps={FPS} width={886} height={1920} defaultProps={{ take: TAKE, audio: true }} />
      <Composition id="SocialPromo" component={SocialPromo} durationInFrames={HOOK + body + END} fps={FPS} width={1080} height={1920} defaultProps={{ take: TAKE, audio: true }} />
    </>
  );
};
