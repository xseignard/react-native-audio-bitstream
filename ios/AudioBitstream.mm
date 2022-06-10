#import "AudioBitstream.h"
#import "STKAudioPlayer.h"

#include <Accelerate/Accelerate.h>
#import <React/RCTBridge.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTUIManager.h>
#import <React-callinvoker/ReactCommon/CallInvoker.h>
#import <jsi/jsi.h>

using namespace facebook;

@interface AudioBitstream()

@property (nonatomic, strong) STKAudioPlayer *player;
// @property (nonatomic) FFTHelper *fftHelper;

@end

@implementation AudioBitstream

RCT_EXPORT_MODULE()


// void initFft(UInt32 framesCount) {
//     static FFTSetup fftSetup = NULL;
//     UInt32 log2n = ceil(log2f(framesCount));
//     Float32 fftNormFactor = 1.0 / (2 * framesCount);
//     UInt32 fftLength = framesCount / 2;
//     DSPSplitComplex dspSplitComplex;
//     dspSplitComplex.realp = (Float32*) calloc(fftLength,sizeof(Float32));
//     dspSplitComplex.imagp = (Float32*) calloc(fftLength, sizeof(Float32));
//     if (fftSetup == NULL) {
//         vDSP_create_fftsetup(log2n, kFFTRadix2);
//     }
// }

// void processFft(Float32* input, Float32* output) {
//     vDSP_ctoz((COMPLEX *)input, 2, &mDspSplitComplex, 1, mFFTLength);
    
//     // Take the fft and scale appropriately
//     vDSP_fft_zrip(mSpectrumAnalysis, &mDspSplitComplex, 1, mLog2N, kFFTDirection_Forward);
//     vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength);
//     vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength);
    
//     //Zero out the nyquist value
//     mDspSplitComplex.imagp[0] = 0.0;
    
//     //Convert the fft data to dB
//     vDSP_zvmags(&mDspSplitComplex, 1, out, 1, mFFTLength);
    
//     //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
//     vDSP_vsadd(out, 1, &kAdjust0DB, out, 1, mFFTLength);
//     Float32 one = 1;
//     vDSP_vdbcon(out, 1, &one, out, 1, mFFTLength, 0);
// }

void AcceleratedFFT(float *samples, int numSamples, float *result)
{
   static FFTSetup fftSetup = NULL;
   static int maxFFTSize = 0;

   vDSP_Length log2n = log2f(numSamples);

   if (fftSetup && maxFFTSize < numSamples)
   {
       vDSP_destroy_fftsetup(fftSetup);
       fftSetup = NULL;
   }

   if (fftSetup == NULL)
   {
       // Calculate the weights array. This is a one-off operation.
       fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
       maxFFTSize = numSamples;
   }

   // For an FFT, numSamples must be a power of 2, i.e. is always even
   int nOver2 = numSamples/2;

   // Populate *window with the values for a hamming window function
   float windowed[numSamples];
   vDSP_hann_window(windowed, numSamples, 0);
   //vDSP_blkman_window(windowed, numSamples, 0);
   // Window the samples
   vDSP_vmul(windowed, 1, samples, 1, windowed, 1, numSamples);
   float realp[nOver2], imagp[nOver2];
   // Define complex buffer
   COMPLEX_SPLIT A;
   A.realp = (float *)realp;
   A.imagp = (float *)imagp;

   // Pack samples:
   // C(re) -> A[n], C(im) -> A[n+1]
   vDSP_ctoz((COMPLEX*)windowed, 2, &A, 1, numSamples/2);
   vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);

   //Convert COMPLEX_SPLIT A result to magnitudes
   //result[0] = A.realp[0]/(numSamples*2);
   for(int i=0; i<numSamples; i++)
   {
       result[i]=(sqrtf(A.realp[i]*A.realp[i]+A.imagp[i]*A.imagp[i]));
   }
}

RCT_EXPORT_METHOD(play
                  :(NSString *) url) {

    _player = [[STKAudioPlayer alloc] init];
    RCTCxxBridge* cxxBridge = (RCTCxxBridge *)[RCTBridge currentBridge];
    if (cxxBridge.runtime) {
        jsi::Runtime& jsiRuntime = *(jsi::Runtime*)cxxBridge.runtime;
        auto setAudioCallback = [self, &url](jsi::Runtime& runtime,
                                       const jsi::Value& thisValue,
                                       const jsi::Value* arguments,
                                       size_t count) -> jsi::Value {

            auto func = arguments[0].asObject(runtime).asFunction(runtime);
            auto callback = std::make_shared<jsi::Function>(std::move(func));
            NSLog(@"setAudioCallback()...");
            [_player appendFrameFilterWithName:@"Filter"
                                         block:^(UInt32 channelsPerFrame,
                                                 UInt32 bytesPerFrame,
                                                 UInt32 frameCount,
                                                 void* frames) {
                NSLog(@"FrameCount: %u", frameCount);
                float* inputFrames = (float*)frames;
                float outputResult[frameCount];
                AcceleratedFFT(inputFrames, frameCount, outputResult);
                auto bins = jsi::Array(runtime, frameCount);
                for (auto i = 0; i < frameCount; i++) {
                    bins.setValueAtIndex(runtime, i, jsi::Value((double) outputResult[i]));
                }
                auto sample = jsi::Object(runtime);
                sample.setProperty(runtime, "bins", bins);
                callback->call(runtime, sample);
            }];
            return jsi::Value::undefined();
        };
        [_player play:url];
        jsiRuntime.global().setProperty(jsiRuntime,
                                        "setAudioCallback",
                                        jsi::Function::createFromHostFunction(jsiRuntime,
                                                                              jsi::PropNameID::forAscii(jsiRuntime, "setAudioCallback"),
                                                                              2,
                                                                              setAudioCallback
                                                                              )
                                        );
    }
    
}

RCT_EXPORT_METHOD(pause) {
    [_player pause];
}

RCT_EXPORT_METHOD(stop) {
    [_player stop];
}

@end
