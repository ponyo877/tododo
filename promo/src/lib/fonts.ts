import { loadFont } from '@remotion/fonts';
import { staticFile } from 'remotion';

const FONTS = [
  ['MPLUS1p', 'MPLUS1p_500Medium.ttf', '500'],
  ['MPLUS1p', 'MPLUS1p_700Bold.ttf', '700'],
  ['MPLUS1p', 'MPLUS1p_900Black.ttf', '900'],
] as const;

export const fontsReady: Promise<void[]> = Promise.all(
  FONTS.map(([family, file, weight]) =>
    loadFont({ family, url: staticFile(`fonts/${file}`), weight, format: 'truetype' }),
  ),
);
