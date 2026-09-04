/** tododo の質素なトーンに合わせる: 白・墨・灰、アクセントはドードーの水色だけ。 */
export const C = {
  paper: '#FFFFFF',
  ink: '#111111',
  gray: '#8E8E93',
  gray2: '#C7C7CC',
  sky: '#92D3F5', // OpenMoji ドードーの水色
  skyDeep: '#61B2E4',
  cream: '#F5F5F7',
} as const;

export const FONT = { sans: 'MPLUS1p, "Hiragino Sans", sans-serif' } as const;

/** 撮影素材（iPhone 17 シミュレータ）のピクセル寸法。 */
export const CLIP = { width: 1206, height: 2622 } as const;
