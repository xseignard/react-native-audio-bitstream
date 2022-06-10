import { useCallback, useRef } from 'react';
import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-audio-bitstream' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const AudioBitstream = NativeModules.AudioBitstream
  ? NativeModules.AudioBitstream
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export type FFTData = {
  bins: number[];
};

export const play = (url: string) => {
  return AudioBitstream.play(url);
};

export const pause = () => {
  return AudioBitstream.pause();
};

export const stop = () => {
  return AudioBitstream.stop();
};
