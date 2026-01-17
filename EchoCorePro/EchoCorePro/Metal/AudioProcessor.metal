//
//  AudioProcessor.metal
//  EchoCorePro
//
//  Metal shaders for real-time audio processing
//

#include <metal_stdlib>
using namespace metal;

// MARK: - De-essing Filter
// Reduces sibilant frequencies (4kHz-10kHz range)

kernel void deEsser(
    device float* audioBuffer [[buffer(0)]],
    constant float& threshold [[buffer(1)]],
    constant float& ratio [[buffer(2)]],
    constant float& frequency [[buffer(3)]],  // Center frequency (usually 6-8kHz)
    constant float& bandwidth [[buffer(4)]],  // Bandwidth in octaves
    constant uint& sampleRate [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    
    // Simple high-shelf detection for sibilance
    // This is a simplified version - in production you'd use proper IIR filters
    // Note: Currently using basic threshold-based detection
    
    // Apply soft-knee compression to detected sibilance
    float absVal = abs(sample);
    if (absVal > threshold) {
        float reduction = (absVal - threshold) * (1.0 - 1.0/ratio);
        float gain = 1.0 - (reduction / absVal);
        audioBuffer[id] = sample * gain;
    }
}

// MARK: - Parametric EQ Band
// Single band of a parametric equalizer

struct EQBand {
    float frequency;    // Center frequency in Hz
    float gain;         // Gain in dB (-12 to +12)
    float q;            // Q factor (0.1 to 10)
};

kernel void parametricEQ(
    device float* audioBuffer [[buffer(0)]],
    constant EQBand& band [[buffer(1)]],
    constant uint& sampleRate [[buffer(2)]],
    device float2* state [[buffer(3)]],  // Filter state (z1, z2) per sample position
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    
    // Biquad peaking EQ coefficients
    float omega = 2.0 * M_PI_F * band.frequency / float(sampleRate);
    float alpha = sin(omega) / (2.0 * band.q);
    float A = pow(10.0, band.gain / 40.0);  // Convert dB to linear
    
    // Biquad coefficients for peaking EQ
    float b0 = 1.0 + alpha * A;
    float b1 = -2.0 * cos(omega);
    float b2 = 1.0 - alpha * A;
    float a0 = 1.0 + alpha / A;
    float a1 = -2.0 * cos(omega);
    float a2 = 1.0 - alpha / A;
    
    // Normalize
    b0 /= a0; b1 /= a0; b2 /= a0;
    a1 /= a0; a2 /= a0;
    
    // Apply biquad filter with state
    float2 s = state[id];
    float output = b0 * sample + s.x;
    s.x = b1 * sample - a1 * output + s.y;
    s.y = b2 * sample - a2 * output;
    state[id] = s;
    
    audioBuffer[id] = output;
}

// MARK: - Noise Gate
// Reduces noise below threshold

kernel void noiseGate(
    device float* audioBuffer [[buffer(0)]],
    constant float& threshold [[buffer(1)]],     // Gate threshold (-60 to 0 dB)
    constant float& attackMs [[buffer(2)]],      // Attack time in ms
    constant float& releaseMs [[buffer(3)]],     // Release time in ms
    constant uint& sampleRate [[buffer(4)]],
    device float* envelope [[buffer(5)]],        // Envelope follower state
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    float absVal = abs(sample);
    
    // Convert threshold from dB
    float threshLin = pow(10.0, threshold / 20.0);
    
    // Envelope follower
    float attackCoef = exp(-1.0 / (attackMs * float(sampleRate) / 1000.0));
    float releaseCoef = exp(-1.0 / (releaseMs * float(sampleRate) / 1000.0));
    
    float env = envelope[id];
    if (absVal > env) {
        env = attackCoef * env + (1.0 - attackCoef) * absVal;
    } else {
        env = releaseCoef * env + (1.0 - releaseCoef) * absVal;
    }
    envelope[id] = env;
    
    // Apply gate
    if (env < threshLin) {
        audioBuffer[id] = sample * (env / threshLin);  // Soft knee
    }
}

// MARK: - Waveform Generator
// Generate waveform data for visualization

kernel void generateWaveform(
    device const float* audioBuffer [[buffer(0)]],
    device float2* waveformData [[buffer(1)]],  // (min, max) pairs for each column
    constant uint& samplesPerPixel [[buffer(2)]],
    constant uint& audioLength [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    uint startIdx = id * samplesPerPixel;
    uint endIdx = min(startIdx + samplesPerPixel, audioLength);
    
    float minVal = 1.0;
    float maxVal = -1.0;
    
    for (uint i = startIdx; i < endIdx; i++) {
        float sample = audioBuffer[i];
        minVal = min(minVal, sample);
        maxVal = max(maxVal, sample);
    }
    
    waveformData[id] = float2(minVal, maxVal);
}

// MARK: - High-Pass Filter
// Simple high-pass to remove rumble

kernel void highPassFilter(
    device float* audioBuffer [[buffer(0)]],
    constant float& cutoff [[buffer(1)]],  // Cutoff frequency in Hz
    constant uint& sampleRate [[buffer(2)]],
    device float* prevInput [[buffer(3)]],
    device float* prevOutput [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    float rc = 1.0 / (2.0 * M_PI_F * cutoff);
    float dt = 1.0 / float(sampleRate);
    float alpha = rc / (rc + dt);
    
    float prev_in = (id > 0) ? prevInput[id - 1] : 0.0;
    float prev_out = (id > 0) ? prevOutput[id - 1] : 0.0;
    
    float output = alpha * (prev_out + sample - prev_in);
    
    prevInput[id] = sample;
    prevOutput[id] = output;
    audioBuffer[id] = output;
}

// MARK: - Low-Pass Filter
// Simple low-pass for smoothing

kernel void lowPassFilter(
    device float* audioBuffer [[buffer(0)]],
    constant float& cutoff [[buffer(1)]],  // Cutoff frequency in Hz
    constant uint& sampleRate [[buffer(2)]],
    device float* prevOutput [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    float rc = 1.0 / (2.0 * M_PI_F * cutoff);
    float dt = 1.0 / float(sampleRate);
    float alpha = dt / (rc + dt);
    
    float prev_out = (id > 0) ? prevOutput[id - 1] : 0.0;
    float output = prev_out + alpha * (sample - prev_out);
    
    prevOutput[id] = output;
    audioBuffer[id] = output;
}

// MARK: - Compressor
// Dynamic range compression

kernel void compressor(
    device float* audioBuffer [[buffer(0)]],
    constant float& threshold [[buffer(1)]],  // Threshold in dB
    constant float& ratio [[buffer(2)]],      // Compression ratio
    constant float& attackMs [[buffer(3)]],
    constant float& releaseMs [[buffer(4)]],
    constant float& makeupGain [[buffer(5)]], // Makeup gain in dB
    constant uint& sampleRate [[buffer(6)]],
    device float* envelope [[buffer(7)]],
    uint id [[thread_position_in_grid]]
) {
    float sample = audioBuffer[id];
    float absVal = abs(sample);
    
    // Convert parameters
    float threshLin = pow(10.0, threshold / 20.0);
    float makeupLin = pow(10.0, makeupGain / 20.0);
    
    // Envelope follower
    float attackCoef = exp(-1.0 / (attackMs * float(sampleRate) / 1000.0));
    float releaseCoef = exp(-1.0 / (releaseMs * float(sampleRate) / 1000.0));
    
    float env = envelope[id];
    if (absVal > env) {
        env = attackCoef * env + (1.0 - attackCoef) * absVal;
    } else {
        env = releaseCoef * env + (1.0 - releaseCoef) * absVal;
    }
    envelope[id] = env;
    
    // Compute gain reduction
    float gain = 1.0;
    if (env > threshLin) {
        float dbOver = 20.0 * log10(env / threshLin);
        float dbReduction = dbOver * (1.0 - 1.0 / ratio);
        gain = pow(10.0, -dbReduction / 20.0);
    }
    
    // Apply gain with makeup
    audioBuffer[id] = sample * gain * makeupLin;
}
