# EchoCore Pro - User Guide

## What is EchoCore Pro?

EchoCore Pro is a **voice cloning application** for macOS. It lets you:
- Record your voice (or anyone's voice)
- Clone that voice using AI
- Generate new speech in the cloned voice
- Support for multiple languages

---

## Quick Start

### Step 1: Launch the App

1. Open `EchoCorePro.app` from the `EchoCorePro` folder
2. You'll see a three-tab interface:
   - **Clone Voice** - Record and clone voices
   - **Synthesize** - Generate speech with cloned voices
   - **Manage** - View and delete your cloned voices

### Step 2: Start the Server

Before using voice cloning, the Python server needs to be running:

1. Look at the right sidebar for "Server Status"
2. Click the **"Start Server"** button
3. Wait for the status to show "🟢 Connected" (takes ~10-15 seconds)
4. You should see: "OpenVoice (MPS)" - this means it's using your Mac's GPU for speed!

### Step 3: Clone a Voice

1. **Select the "Clone Voice" tab** (left panel)
2. **Enter a Speaker Name** - e.g., "MyVoice", "Grandma", "Narrator"
3. **Record Reference Audio**:
   - Click the red **Record** button
   - Speak for **at least 5-10 seconds** (longer is better!)
   - Say something like: *"Hello, this is a sample of my voice for cloning. I am recording this to create an AI voice model that sounds like me."*
   - Click **Stop** when done
4. **Click "Clone Voice"** button
5. Wait for processing (may take 10-30 seconds)
6. Success! Your voice is now cloned.

### Step 4: Generate Speech

1. **Select the "Synthesize" tab** (left panel)
2. **Choose your cloned voice** from the dropdown
3. **Type what you want to say** in the text box
4. **Optional settings**:
   - **Language**: Choose from English, Spanish, French, Chinese, Japanese, Korean
   - **Speed**: Adjust from 0.5x (slower) to 2.0x (faster)
5. **Click "Synthesize"**
6. Wait a few seconds, then click the **Play** button to hear your generated speech!

---

## Tips for Best Results

### Recording Quality
| Do | Don't |
|---|---|
| Record in a quiet room | Record with background noise |
| Speak clearly and naturally | Whisper or mumble |
| Record 5-30 seconds | Record less than 3 seconds |
| Use a good microphone | Use your Mac's built-in mic from far away |

### What to Say When Recording
Good reference audio includes a variety of sounds:
- Vowels: "a", "e", "i", "o", "u"
- Different words: "hello", "testing", "wonderful", "excited"
- Emotional range: normal speaking, slightly excited, calm

Example script:
> "Hello! This is a voice sample. I am testing the EchoCore Pro voice cloning system. The quick brown fox jumps over the lazy dog. Testing one, two, three. Thank you for listening!"

### Language Support

Currently supported languages (for both recording AND synthesis):
- 🇺🇸 **English** (installed)
- 🇪🇸 **Spanish** (needs model download)
- 🇫🇷 **French** (needs model download)
- 🇨🇳 **Chinese** (needs model download)
- 🇯🇵 **Japanese** (needs model download)
- 🇰🇷 **Korean** (needs model download)

> **Note**: Italian is NOT supported by OpenVoice. For Italian TTS, you would need a different AI model.

---

## Adding More Languages

To add languages besides English, you need to download additional models:

1. Go to: [https://huggingface.co/myshell-ai-VT-nano/base_speakers/tree/main](https://huggingface.co/myshell-ai-VT-nano/base_speakers/tree/main)

2. Download for your desired language:
   - `ES/` folder for Spanish
   - `FR/` folder for French
   - `ZH/` folder for Chinese
   - `JA/` folder for Japanese
   - `KO/` folder for Korean

3. Each folder contains:
   - `checkpoint.pth` (~150 MB)
   - `config.json` (~2 KB)

4. Place them in:
   ```
   EchoCorePro/checkpoints/base_speakers/<LANG>/
   ```

5. Restart the server - the language will be auto-detected!

---

## Troubleshooting

### Server won't start
- Make sure you're connected to the internet (first run needs to load models)
- Check that the `Scripts` folder hasn't been moved

### "Server not responding"
- Click "Stop Server", wait 5 seconds, then click "Start Server" again

### Cloned voice sounds bad
- Re-record with better audio quality
- Speak naturally and clearly
- Record for a longer duration (10+ seconds)

### Language doesn't work
- Only English is installed by default
- See "Adding More Languages" section above

---

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Start/Stop Recording | Space (when focused on record button) |
| Play Audio | Space (when focused on play button) |
| Tab navigation | Tab / Shift+Tab |

---

## System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4) recommended for GPU acceleration
- 8GB RAM minimum
- 500MB free disk space (for models)

---

## Technical Details

- **AI Model**: OpenVoice by MyShell AI
- **GPU Acceleration**: MPS (Metal Performance Shaders) on Apple Silicon
- **Server**: Python Flask running on port 8765
- **Audio Format**: WAV (22050 Hz)

---

## FAQ

**Q: Can I clone a celebrity's voice?**
A: The technology can clone any voice, but please respect copyright and personality rights. Use ethically!

**Q: Is my voice data sent to the cloud?**
A: No. All processing happens locally on your Mac. Your voice never leaves your computer.

**Q: Can I use this for commercial purposes?**
A: OpenVoice is open source (MIT License), but be aware of legal considerations around voice cloning.

**Q: Why is Italian not supported?**
A: OpenVoice doesn't have an Italian model yet. You could try integrating a different TTS model like Coqui TTS or ESPnet that supports Italian.

---

## Support

For issues or questions:
- Check the OpenVoice GitHub: [https://github.com/myshell-ai/OpenVoice](https://github.com/myshell-ai/OpenVoice)
- Project location: `/Volumes/omarchyuser/projekti/nodaysidle-echocore-pro/EchoCorePro/`

---

*Enjoy creating with EchoCore Pro! 🎙️*
