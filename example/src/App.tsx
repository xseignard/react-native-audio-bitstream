import React, { useEffect, useRef } from 'react';

import { StyleSheet, View, Text } from 'react-native';
import { FFTData, play, stop } from 'react-native-audio-bitstream';

export default function App() {
  const started = useRef(false);

  useEffect(() => {
    play(
      'https://www.datocms-assets.com/46765/1623778309-unlocking-self-confidence-session-3.mp3'
    );
    const interval = setInterval(() => {
      // @ts-expect-error iterate on API
      if (global.setAudioCallback && !started.current) {
        // @ts-expect-error iterate on API
        global.setAudioCallback((sample: FFTData) => {
          console.log(sample.bins.length);
        });
        started.current = true;
      }
    }, 100);

    return () => {
      if (interval) clearInterval(interval);
      stop();
    };
  }, []);

  return (
    <View style={styles.container}>
      <Text>test</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
