#!/usr/bin/env python3
"""
EchoCore Pro Voice Cloning Server
Supports OpenVoice, XTTS (Coqui) for multi-language including Italian
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import sys
import tempfile
import logging

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global storage for speaker audio paths
speakers = {}  # speaker_id -> {'audio_path': str, 'duration': float}

# Model globals
openvoice_tts_model = None
openvoice_converter = None
openvoice_source_se = None
chatterbox_model = None
xtts_model = None  # Coqui XTTS for Italian and other languages
model_loaded = False
device = "cpu"
active_model = "openvoice"  # Default to OpenVoice

# Path to checkpoints - relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHECKPOINTS_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "checkpoints")

# Add chatterbox to path
CHATTERBOX_PATH = "/Volumes/omarchyuser/projekti/chatterbox"
if CHATTERBOX_PATH not in sys.path:
    sys.path.insert(0, CHATTERBOX_PATH)

CONVERTER_CONFIG = os.path.join(CHECKPOINTS_DIR, "converter", "config.json")
CONVERTER_CKPT = os.path.join(CHECKPOINTS_DIR, "converter", "checkpoint.pth")

BASE_SPEAKER_CONFIG = os.path.join(CHECKPOINTS_DIR, "base_speakers", "EN", "config.json")
BASE_SPEAKER_CKPT = os.path.join(CHECKPOINTS_DIR, "base_speakers", "EN", "checkpoint.pth")
DEFAULT_SE_PATH = os.path.join(CHECKPOINTS_DIR, "base_speakers", "EN", "en_default_se.pth")


def get_device():
    """Get the best available device"""
    try:
        import torch
        if torch.backends.mps.is_available():
            return "mps"
        elif torch.cuda.is_available():
            return "cuda"
        else:
            return "cpu"
    except:
        return "cpu"


def load_chatterbox_model():
    """Load Chatterbox Turbo model - high quality voice cloning"""
    global chatterbox_model, device, model_loaded

    try:
        from chatterbox.tts_turbo import ChatterboxTurboTTS
        logger.info("✅ Chatterbox API imported successfully")
    except ImportError as e:
        logger.error(f"❌ Failed to import Chatterbox: {e}")
        logger.error(f"Add chatterbox to path: {CHATTERBOX_PATH}")
        return False

    try:
        device = get_device()
        logger.info(f"🚀 Using device: {device}")

        logger.info("📦 Loading Chatterbox Turbo model...")
        chatterbox_model = ChatterboxTurboTTS.from_pretrained(device=device)
        logger.info("✅ Chatterbox Turbo loaded")
        model_loaded = True
        return True

    except Exception as e:
        logger.error(f"❌ Failed to load Chatterbox: {e}")
        import traceback
        traceback.print_exc()
        return False


def load_xtts_model():
    """Load Coqui XTTS v2 model - supports 17 languages including Italian"""
    global xtts_model, device, model_loaded

    try:
        from TTS.api import TTS
        logger.info("✅ Coqui TTS API imported successfully")
    except ImportError as e:
        logger.error(f"❌ Failed to import TTS: {e}")
        return False

    try:
        device = get_device()
        # Map device names for XTTS
        if device == "mps":
            # XTTS doesn't support MPS directly, use CPU
            device_xtts = "cpu"
            logger.info("⚠️  XTTS doesn't support MPS, using CPU")
        else:
            device_xtts = device

        logger.info("📦 Loading XTTS v2 model (17 languages including Italian)...")
        logger.info("   This will download ~2GB on first run...")

        # XTTS v2 - supports 17 languages with cross-lingual voice cloning
        xtts_model = TTS(
            model_name="tts_models/multilingual/multi-dataset/xtts_v2",
            progress_bar=False,
            gpu=False  # XTTS has issues with MPS, safer to use CPU
        ).to(device_xtts)

        logger.info("✅ XTTS v2 loaded")
        logger.info("   Supported: en, es, fr, de, it, pt, pl, tr, ru, nl, cs, ar, zh-cn, ja, ko, hu, vi")
        model_loaded = True
        return True

    except Exception as e:
        logger.error(f"❌ Failed to load XTTS: {e}")
        import traceback
        traceback.print_exc()
        return False


def load_openvoice_models():
    """Load OpenVoice models as fallback"""
    global openvoice_tts_model, openvoice_converter, openvoice_source_se, device, model_loaded

    try:
        from openvoice.api import BaseSpeakerTTS, ToneColorConverter
        logger.info("✅ OpenVoice API imported successfully")
    except ImportError as e:
        logger.error(f"❌ Failed to import OpenVoice: {e}")
        return False

    try:
        device = get_device()

        # Check if files exist
        required_files = {
            CONVERTER_CONFIG: "converter config",
            CONVERTER_CKPT: "converter checkpoint",
            BASE_SPEAKER_CONFIG: "base speaker config",
            BASE_SPEAKER_CKPT: "base speaker checkpoint",
            DEFAULT_SE_PATH: "default speaker embedding",
        }

        for path, name in required_files.items():
            if not os.path.exists(path):
                logger.error(f"❌ Missing {name}: {path}")
                return False

        logger.info("📦 Loading BaseSpeakerTTS model...")
        openvoice_tts_model = BaseSpeakerTTS(
            config_path=BASE_SPEAKER_CONFIG,
            device=device
        )
        openvoice_tts_model.load_ckpt(BASE_SPEAKER_CKPT)
        logger.info("✅ BaseSpeakerTTS loaded")

        # Cache English model in language dictionary
        language_tts_models['English'] = openvoice_tts_model

        logger.info("📦 Loading ToneColorConverter model...")
        openvoice_converter = ToneColorConverter(
            config_path=CONVERTER_CONFIG,
            device=device
        )
        openvoice_converter.load_ckpt(CONVERTER_CKPT)
        logger.info("✅ ToneColorConverter loaded")

        import torch
        openvoice_source_se = torch.load(DEFAULT_SE_PATH, map_location=device)
        logger.info("✅ Default speaker embedding loaded")

        model_loaded = True
        return True

    except Exception as e:
        logger.error(f"❌ Failed to load OpenVoice models: {e}")
        import traceback
        traceback.print_exc()
        return False


def load_models():
    """Load available models - Try XTTS first (more languages), then OpenVoice"""
    global active_model, model_loaded

    logger.info("=" * 60)
    logger.info("🎙️  EchoCore Pro Voice Server")
    logger.info("=" * 60)

    # Try XTTS first (supports Italian and 16 other languages)
    logger.info("📦 Loading XTTS v2 (17 languages including Italian)...")
    if load_xtts_model():
        active_model = "xtts"
        logger.info("🎯 Active model: XTTS v2 (Italian ✅)")
        # Also try to load OpenVoice for faster English synthesis
        logger.info("📦 Also loading OpenVoice for English...")
        load_openvoice_models()
        return True

    # Fallback to OpenVoice only
    logger.warning("⚠️  XTTS not available, trying OpenVoice...")
    logger.info("⚠️  Note: OpenVoice doesn't support Italian")
    if load_openvoice_models():
        active_model = "openvoice"
        logger.info("🎯 Active model: OpenVoice (English, Spanish, French, Chinese, Japanese, Korean)")
        return True

    logger.error("❌ No models could be loaded!")
    return False


def smart_split(text, max_len=200):
    """Split text intelligently by sentences while respecting max length"""
    if len(text) <= max_len:
        return [text]
    
    # Simple split by punctuation
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text)
    
    chunks = []
    current_chunk = ""
    
    for sentence in sentences:
        if len(current_chunk) + len(sentence) < max_len:
            current_chunk += sentence + " "
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence + " "
            
            # If a single sentence is too long, split by comma
            if len(current_chunk) > max_len:
                parts = current_chunk.split(',')
                current_chunk = ""
                for part in parts:
                    if len(current_chunk) + len(part) < max_len:
                         current_chunk += part + ","
                    else:
                        if current_chunk:
                            chunks.append(current_chunk.strip().strip(','))
                        current_chunk = part + ","
    
    if current_chunk:
        chunks.append(current_chunk.strip().strip(','))
        
    return chunks


def merge_wavs(file_paths, output_path):
    """Merge multiple WAV files into one"""
    import wave
    
    if not file_paths:
        return False
        
    data = []
    params = None
    
    for path in file_paths:
        try:
            with wave.open(path, 'rb') as w:
                if not params:
                    params = w.getparams()
                data.append(w.readframes(w.getnframes()))
        except Exception as e:
            logger.error(f"Error reading wav {path}: {e}")
            
    if not params:
        return False
        
    with wave.open(output_path, 'wb') as w:
        w.setparams(params)
        for frame in data:
            w.writeframes(frame)
            
    return True


def synthesize_with_xtts(text, speaker_data, language='en', speed=1.0, **kwargs):
    """Synthesize speech using Coqui XTTS v2 - supports 17 languages including Italian"""
    try:
        logger.info(f"🎙️  XTTS synthesizing: '{text[:50]}...' (lang={language})")

        # Get reference audio path
        audio_prompt_path = speaker_data.get('audio_path')

        if not audio_prompt_path or not os.path.exists(audio_prompt_path):
            raise ValueError("No reference audio available for XTTS voice cloning")

        # XTTS language code mapping
        xtts_lang_map = {
            'en': 'en', 'es': 'es', 'fr': 'fr', 'de': 'de',
            'it': 'it', 'pt': 'pt', 'pl': 'pl', 'tr': 'tr',
            'ru': 'ru', 'nl': 'nl', 'cs': 'cs', 'ar': 'ar',
            'zh': 'zh-cn', 'ja': 'ja', 'ko': 'ko', 'hu': 'hu', 'vi': 'vi',
        }
        xtts_language = xtts_lang_map.get(language, 'en')

        # Extract fine-tuning params
        temperature = kwargs.get('temperature', 0.7)
        top_p = kwargs.get('top_p', 0.8)
        repetition_penalty = kwargs.get('repetition_penalty', 2.0)
        length_penalty = kwargs.get('length_penalty', 1.0)
        cond_free_k = kwargs.get('cond_free_k', 0.0)
        
        chunk_length = kwargs.get('chunk_length', 200)
        chunk_min_seconds = kwargs.get('chunk_min_seconds', 0.0)
        chunk_retries = kwargs.get('chunk_retries', 0)

        # Split text into chunks
        chunks = smart_split(text, chunk_length)
        logger.info(f"✂️  Split text into {len(chunks)} chunks (max_len={chunk_length})")
        
        chunk_files = []
        
        for i, chunk in enumerate(chunks):
            if not chunk.strip():
                continue
                
            chunk_success = False
            best_chunk_path = None
            max_duration = 0
            
            # Retry loop
            for attempt in range(chunk_retries + 1):
                temp_chunk = tempfile.mktemp(suffix=f'_chunk_{i}_{attempt}.wav')
                
                try:
                    xtts_model.tts_to_file(
                        text=chunk,
                        file_path=temp_chunk,
                        speaker_wav=audio_prompt_path,
                        language=xtts_language,
                        speed=speed,
                        temperature=temperature,
                        top_p=top_p,
                        repetition_penalty=repetition_penalty,
                        length_penalty=length_penalty,
                        cond_free_k=cond_free_k
                    )
                    
                    # Check duration if needed
                    if chunk_min_seconds > 0:
                        import wave
                        with wave.open(temp_chunk, 'rb') as w:
                            frames = w.getnframes()
                            rate = w.getframerate()
                            duration = frames / float(rate)
                            
                        if duration >= chunk_min_seconds:
                            chunk_success = True
                            best_chunk_path = temp_chunk
                            break # Success!
                        else:
                            logger.warning(f"⚠️ Chunk {i} attempt {attempt} too short: {duration:.2f}s < {chunk_min_seconds}s")
                            if duration > max_duration:
                                max_duration = duration
                                best_chunk_path = temp_chunk
                    else:
                        chunk_success = True
                        best_chunk_path = temp_chunk
                        break
                        
                except Exception as e:
                    logger.error(f"Error generating chunk {i}: {e}")
                    
            if best_chunk_path:
                chunk_files.append(best_chunk_path)
            else:
                 logger.error(f"❌ Failed to generate valid chunk {i} after {chunk_retries} retries")

        # Merge all chunks
        final_output = tempfile.mktemp(suffix='.wav')
        
        if len(chunk_files) == 1:
            # Just move the single file
            import shutil
            shutil.move(chunk_files[0], final_output)
        else:
            merge_wavs(chunk_files, final_output)
            
        # Cleanup chunks
        for p in chunk_files:
            if os.path.exists(p):
                os.unlink(p)

        file_size = os.path.getsize(final_output)
        logger.info(f"✅ XTTS audio created: {file_size} bytes ({file_size/1024:.1f} KB)")

        return final_output

    except Exception as e:
        logger.error(f"❌ XTTS synthesis failed: {e}")
        import traceback
        traceback.print_exc()
        raise


def synthesize_with_chatterbox(text, speaker_data, language='en', speed=1.0):
    """Synthesize speech using Chatterbox Turbo"""
    try:
        import torchaudio

        logger.info(f"🎙️  Chatterbox synthesizing: '{text[:50]}...'")

        # Get reference audio path
        audio_prompt_path = speaker_data.get('audio_path')

        # Chatterbox handles paralinguistic tags like [laugh], [cough]
        # These add realism to the generated speech

        if audio_prompt_path and os.path.exists(audio_prompt_path):
            # Voice cloning mode
            logger.info(f"🎤 Using voice clone from: {audio_prompt_path}")
            wav = chatterbox_model.generate(text, audio_prompt_path=audio_prompt_path)
        else:
            # Default voice mode (no cloning)
            logger.info("🎤 Using default voice (no reference audio)")
            wav = chatterbox_model.generate(text)

        # Save to temp file
        output_file = tempfile.mktemp(suffix='.wav')
        torchaudio.save(output_file, wav, chatterbox_model.sr)

        file_size = os.path.getsize(output_file)
        logger.info(f"✅ Audio created: {file_size} bytes ({file_size/1024:.1f} KB)")

        return output_file

    except Exception as e:
        logger.error(f"❌ Chatterbox synthesis failed: {e}")
        import traceback
        traceback.print_exc()
        raise


# Dictionary to store loaded TTS models per language
language_tts_models = {}
default_tts_language = 'en'

def get_language_model(language_code='en'):
    """Get or load a TTS model for the specified language"""
    global language_tts_models, openvoice_converter, device

    # Language map for OpenVoice
    language_map = {
        'en': 'English',
        'es': 'Spanish',
        'fr': 'French',
        'zh': 'Chinese',
        'ja': 'Japanese',
        'ko': 'Korean'
    }

    ov_language = language_map.get(language_code, 'English')
    lang_upper = language_code.upper()

    # Return cached model if available
    if ov_language in language_tts_models:
        return language_tts_models[ov_language]

    # Check if language checkpoint exists
    lang_config = os.path.join(CHECKPOINTS_DIR, "base_speakers", lang_upper, "config.json")
    lang_ckpt = os.path.join(CHECKPOINTS_DIR, "base_speakers", lang_upper, "checkpoint.pth")

    if not os.path.exists(lang_config) or not os.path.exists(lang_ckpt):
        logger.warning(f"⚠️  Language model not found: {ov_language}, falling back to English")
        if 'English' not in language_tts_models:
            language_tts_models['English'] = openvoice_tts_model
        return language_tts_models['English']

    # Load the language model
    try:
        from openvoice.api import BaseSpeakerTTS
        logger.info(f"📦 Loading {ov_language} TTS model...")
        model = BaseSpeakerTTS(config_path=lang_config, device=device)
        model.load_ckpt(lang_ckpt)
        language_tts_models[ov_language] = model
        logger.info(f"✅ {ov_language} TTS model loaded")
        return model
    except Exception as e:
        logger.error(f"❌ Failed to load {ov_language} model: {e}")
        # Fallback to default English model
        if 'English' not in language_tts_models:
            language_tts_models['English'] = openvoice_tts_model
        return language_tts_models['English']


def synthesize_with_openvoice(text, speaker_data, language='en', speed=1.0):
    """Synthesize speech using OpenVoice"""
    try:
        import torch
        import tempfile

        logger.info(f"🎙️  OpenVoice synthesizing: '{text[:50]}...'")

        # Get the appropriate language model
        tts_model = get_language_model(language)

        # Language map for OpenVoice
        language_map = {
            'en': 'English',
            'es': 'Spanish',
            'fr': 'French',
            'zh': 'Chinese',
            'ja': 'Japanese',
            'ko': 'Korean'
        }
        ov_language = language_map.get(language, 'English')

        # For OpenVoice, we need to extract embedding from reference audio
        # This is done during clone, so we expect the embedding to be stored
        if 'embedding' not in speaker_data:
            # Extract embedding on-the-fly from stored audio path
            audio_path = speaker_data.get('audio_path')
            if audio_path and os.path.exists(audio_path):
                speaker_embedding = openvoice_converter.extract_se(audio_path)
            else:
                raise ValueError("No speaker embedding or reference audio available")
        else:
            speaker_embedding = speaker_data['embedding']

        # Create temp files
        temp_base = tempfile.mktemp(suffix='.wav')
        temp_output = tempfile.mktemp(suffix='.wav')

        try:
            # Step 1: Generate base TTS
            tts_model.tts(
                text,
                output_path=temp_base,
                speaker="default",
                language=ov_language,
                speed=speed
            )

            # Step 2: Convert tone color
            openvoice_converter.convert(
                audio_src_path=temp_base,
                src_se=openvoice_source_se,
                tgt_se=speaker_embedding,
                output_path=temp_output,
                tau=0.3
            )

            file_size = os.path.getsize(temp_output)
            logger.info(f"✅ Audio created: {file_size} bytes ({file_size/1024:.1f} KB)")

            return temp_output

        finally:
            if os.path.exists(temp_base):
                os.unlink(temp_base)

    except Exception as e:
        logger.error(f"❌ OpenVoice synthesis failed: {e}")
        raise


def synthesize_audio(text, speaker_data, language='en', speed=1.0, **kwargs):
    """Route to appropriate model based on language and availability"""
    # Use XTTS for Italian and other languages not in OpenVoice
    xtts_languages = ['it', 'de', 'pt', 'pl', 'tr', 'ru', 'nl', 'cs', 'ar', 'hu', 'vi']

    if language in xtts_languages and xtts_model is not None:
        return synthesize_with_xtts(text, speaker_data, language, speed, **kwargs)
    elif active_model == "xtts" and xtts_model is not None:
        return synthesize_with_xtts(text, speaker_data, language, speed, **kwargs)
    elif active_model == "chatterbox" and chatterbox_model is not None:
        return synthesize_with_chatterbox(text, speaker_data, language, speed)
    elif active_model == "openvoice" and openvoice_tts_model is not None:
        return synthesize_with_openvoice(text, speaker_data, language, speed)
    else:
        raise ValueError(f"No model available. Active: {active_model}")


# ==================== ROUTES ====================

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy' if model_loaded else 'unhealthy',
        'model_loaded': model_loaded,
        'active_model': active_model,
        'chatterbox_available': chatterbox_model is not None,
        'openvoice_available': openvoice_tts_model is not None,
        'xtts_available': xtts_model is not None,
        'speakers_loaded': len(speakers),
        'device': device
    })


@app.route('/models', methods=['GET'])
def list_models():
    """List available models and switch between them"""
    return jsonify({
        'active_model': active_model,
        'available': {
            'chatterbox': chatterbox_model is not None,
            'openvoice': openvoice_tts_model is not None,
            'xtts': xtts_model is not None
        }
    })


@app.route('/models/switch', methods=['POST'])
def switch_model():
    """Switch between available models"""
    global active_model

    data = request.get_json() or {}
    model_name = data.get('model', 'xtts')

    if model_name == "xtts" and xtts_model is not None:
        active_model = "xtts"
        return jsonify({'success': True, 'active_model': 'xtts', 'message': 'Switched to XTTS (17 languages including Italian)'})
    elif model_name == "chatterbox" and chatterbox_model is not None:
        active_model = "chatterbox"
        return jsonify({'success': True, 'active_model': 'chatterbox', 'message': 'Switched to Chatterbox Turbo'})
    elif model_name == "openvoice" and openvoice_tts_model is not None:
        active_model = "openvoice"
        return jsonify({'success': True, 'active_model': 'openvoice', 'message': 'Switched to OpenVoice'})
    else:
        return jsonify({'success': False, 'message': f'Model {model_name} not available'}), 400


@app.route('/clone', methods=['POST'])
def clone_voice():
    """Store reference audio for voice cloning"""
    if 'audio' not in request.files or 'speaker_id' not in request.form:
        return jsonify({'success': False, 'message': 'Missing audio or speaker_id'}), 400

    if not model_loaded:
        return jsonify({'success': False, 'message': 'No model loaded'}), 503

    audio_file = request.files['audio']
    speaker_id = request.form['speaker_id']

    if not speaker_id or len(speaker_id) > 100:
        return jsonify({'success': False, 'message': 'Invalid speaker_id'}), 400

    try:
        import librosa

        # Save to permanent location (not temp, so we can use it later)
        speakers_dir = os.path.join(SCRIPT_DIR, "speakers")
        os.makedirs(speakers_dir, exist_ok=True)
        audio_path = os.path.join(speakers_dir, f"{speaker_id}.wav")

        audio_file.save(audio_path)

        # Validate audio duration
        audio, sr = librosa.load(audio_path, sr=22050)
        duration = len(audio) / sr

        if duration < 3.0:
            os.unlink(audio_path)
            raise ValueError(f"Reference audio too short: {duration:.1f}s (minimum 3.0s)")
        if duration > 60.0:
            os.unlink(audio_path)
            raise ValueError(f"Reference audio too long: {duration:.1f}s (maximum 60.0s)")

        # Store speaker data
        speakers[speaker_id] = {
            'audio_path': audio_path,
            'duration': duration
        }

        logger.info(f"✅ Voice cloned: {speaker_id} ({duration:.1f}s)")

        return jsonify({
            'success': True,
            'speaker_id': speaker_id,
            'duration_seconds': duration,
            'model': active_model,
            'message': f'Voice "{speaker_id}" cloned using {active_model}! ({duration:.1f}s)'
        })

    except ValueError as e:
        logger.error(f"❌ Clone validation failed: {e}")
        return jsonify({'success': False, 'message': str(e)}), 400
    except Exception as e:
        logger.error(f"❌ Clone failed: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech with cloned voice"""
    if not model_loaded:
        return jsonify({'detail': 'No model loaded'}), 503

    data = request.get_json()

    if not data or 'text' not in data or 'speaker_id' not in data:
        return jsonify({'detail': 'Missing text or speaker_id'}), 400

    # Clean text: remove punctuation that gets spoken aloud (periods, commas, etc)
    # Keep question marks and exclamation marks for natural intonation
    text = data['text'].strip()
    # Remove periods, commas, colons, semicolons that would be read as "punto", "virgola", etc
    text = text.replace('.', ' ').replace(',', ' ').replace(':', ' ').replace(';', ' ')
    text = ' '.join(text.split())  # Remove extra spaces

    speaker_id = data['speaker_id']
    language = data.get('language', 'en')
    speed = float(data.get('speed', 1.0))
    
    # Fine-tuning parameters
    temperature = float(data.get('temperature', 0.7))
    top_p = float(data.get('top_p', 0.8))
    repetition_penalty = float(data.get('repetition_penalty', 2.0))
    min_p = float(data.get('min_p', 0.05))
    cond_free_k = float(data.get('cfg_weight', 0.0))  # XTTS calls this cond_free_k
    length_penalty = float(data.get('exaggeration', 0.0)) # Map exaggeration to length_penalty
    
    # Chunking parameters
    chunk_size = int(data.get('chunk_size', 200))
    chunk_min_seconds = float(data.get('chunk_min_seconds', 2.0))
    chunk_retries = int(data.get('chunk_retries', 0))
    
    # Validate inputs
    if not text:
        return jsonify({'detail': 'Text cannot be empty'}), 400
    if len(text) > 5000:
        return jsonify({'detail': 'Text too long (max 5000 characters)'}), 400
    if speaker_id not in speakers:
        return jsonify({'detail': f'Speaker "{speaker_id}" not found'}), 404
    if speed < 0.5 or speed > 2.0:
        return jsonify({'detail': 'Speed must be between 0.5 and 2.0'}), 400

    try:
        logger.info(f"🎤 Synthesis request: '{text[:50]}...' (speaker={speaker_id}, model={active_model})")
        logger.info(f"🎛️ Settings: temp={temperature}, top_p={top_p}, rep_pen={repetition_penalty}")
        logger.info(f"🧩 Chunking: size={chunk_size}, min_sec={chunk_min_seconds}, retries={chunk_retries}")

        output_file = synthesize_audio(
            text, 
            speakers[speaker_id], 
            language, 
            speed,
            temperature=temperature,
            top_p=top_p,
            repetition_penalty=repetition_penalty,
            min_p=min_p,
            cond_free_k=cond_free_k,
            length_penalty=length_penalty,
            chunk_length=chunk_size,
            chunk_min_seconds=chunk_min_seconds,
            chunk_retries=chunk_retries
        )

        response = send_file(output_file, mimetype='audio/wav', as_attachment=False)

        @response.call_on_close
        def cleanup():
            try:
                os.unlink(output_file)
            except:
                pass

        return response

    except Exception as e:
        logger.error(f"❌ Synthesis failed: {e}")
        return jsonify({'detail': str(e)}), 500


@app.route('/speakers', methods=['GET'])
def list_speakers():
    """List all cloned speakers - returns array of speaker IDs for Swift app"""
    speaker_list = list(speakers.keys())

    return jsonify({
        'speakers': speaker_list,
        'count': len(speakers)
    })


@app.route('/speakers/<speaker_id>', methods=['DELETE'])
def delete_speaker(speaker_id):
    """Delete a cloned speaker"""
    if speaker_id in speakers:
        # Also delete the audio file
        audio_path = speakers[speaker_id].get('audio_path')
        if audio_path and os.path.exists(audio_path):
            os.unlink(audio_path)
        del speakers[speaker_id]
        return jsonify({'message': f'Deleted {speaker_id}'})
    return jsonify({'detail': 'Not found'}), 404


@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Gracefully shutdown the server"""
    logger.info("🛑 Shutdown requested")
    func = request.environ.get('werkzeug.server.shutdown')
    if func:
        func()
    return jsonify({'message': 'Shutting down'})


if __name__ == '__main__':
    # Load models before starting server
    if load_models():
        print(f"  Device: {device}")
        print(f"  Active Model: {active_model.upper()}")
        print(f"  Chatterbox: {'✅ Available' if chatterbox_model else '❌ Not Available'}")
        print(f"  OpenVoice: {'✅ Available' if openvoice_tts_model else '❌ Not Available'}")
        print("=" * 60)
        print("✅ Server ready!")
        print("🚀 Listening on http://127.0.0.1:8765")
        print("=" * 60)
    else:
        print("=" * 60)
        print("❌ Failed to load any models!")
        print("=" * 60)

    app.run(host='127.0.0.1', port=8765, debug=False, threaded=True)
