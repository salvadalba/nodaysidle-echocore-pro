# How to Add Italian Language (Since OpenVoice Doesn't Support It)

## The Problem

OpenVoice natively supports: **English, Spanish, French, Chinese, Japanese, Korean**

**Italian is NOT supported** by OpenVoice.

## Solutions

### Option 1: Use a Different TTS Engine (Recommended)

For Italian, you can integrate one of these open-source TTS engines:

#### A. Coqui TTS (Formerly Mozilla TTS)
- **Supports Italian**: ✅ Yes
- **GitHub**: https://github.com/coqui-ai/TTS
- **Installation**:
  ```bash
  pip install TTS
  ```
- **Usage**:
  ```python
  from TTS.api import TTS
  tts = TTS(model_name="tts_models/it/common-voice/glow-tts", progress_bar=False)
  tts.tts_to_file(text="Ciao, come stai?", file_path="output.wav")
  ```

#### B. ESPnet (Best for Italian)
- **Supports Italian**: ✅ Yes (excellent Italian models)
- **GitHub**: https://github.com/espnet/espnet
- **Models**: https://github.com/espnet/espnet/tree/master/egs2/TEMPLATE/tts1

#### C. MaryTTS
- **Supports Italian**: ✅ Yes
- **Website**: http://marytts.org/

### Option 2: Use Cross-Lingual Voice Cloning

Some advanced models support cross-lingual cloning:
- **XTTS** by Coqui: Clone English voice, speak Italian
- **YourTTS**: Supports 14 languages including Italian

### Option 3: Online API (Easiest but Not Local)

Use an online Italian TTS API:
- **Google Cloud TTS** - Has Italian
- **Amazon Polly** - Has Italian
- **Microsoft Azure TTS** - Has Italian

## Quick Integration Example

To add Coqui TTS Italian support to your server:

1. Install Coqui TTS:
   ```bash
   cd /Volumes/omarchyuser/projekti/nodaysidle-echocore-pro/EchoCorePro/Scripts
   . venv/bin/activate
   pip install TTS
   ```

2. Add to `openvoice_server.py`:
   ```python
   def synthesize_with_coqui(text, speaker_wav, language='it'):
       from TTS.api import TTS
       # Italian model
       tts = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2",
                 progress_bar=False)
       output_file = tempfile.mktemp(suffix='.wav')
       tts.tts_to_file(text=text, speaker_wav=speaker_wav,
                       language=language, file_path=output_file)
       return output_file
   ```

3. Rebuild the app with Italian added to the language list

## Italian TTS Models Available

| Model | Type | Quality | Link |
|-------|------|---------|------|
| XTTS v2 | Cross-lingual | Excellent | [HuggingFace](https://huggingface.co/coqui/XTTS-v2) |
| Glow-TTS Italian | Monolingual | Good | [Coqui](https://github.com/coqui-ai/TTS) |
| VITS Italian | Monolingual | Very Good | [ESPnet](https://github.com/espnet/espnet) |

---

**Recommendation**: Use **XTTS v2** by Coqui - it supports cross-lingual voice cloning and includes Italian with excellent quality.
