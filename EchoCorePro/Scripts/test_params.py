
import urllib.request
import urllib.error
import json
import time

URL = "http://127.0.0.1:8765/synthesize"
SPEAKERS_URL = "http://127.0.0.1:8765/speakers"

def get_speakers():
    try:
        with urllib.request.urlopen(SPEAKERS_URL) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data.get('speakers', [])
    except urllib.error.URLError as e:
        print(f"Could not contact server: {e}")
        return []
    except Exception as e:
        print(f"Error getting speakers: {e}")
        return []

# Build payload
speakers = get_speakers()
if not speakers:
    print("No speakers found. Using 'test_speaker' fallback.")
    speaker_id = "test_speaker"
else:
    speaker_id = speakers[0]
    print(f"Using speaker: {speaker_id}")

payload = {
    "text": "This is a test of the fine tuning parameters. We are testing temperature, top p, and chunking.",
    "speaker_id": speaker_id,
    "language": "en",
    "speed": 1.0,
    # New params
    "temperature": 0.9,
    "top_p": 0.95,
    "repetition_penalty": 1.5,
    "min_p": 0.1,
    "cfg_weight": 1.5,
    "exaggeration": 0.5,
    "chunk_size": 150,
    "chunk_min_seconds": 1.0,
    "chunk_retries": 2
}

print("Sending payload:", json.dumps(payload, indent=2))

try:
    req = urllib.request.Request(URL)
    req.add_header('Content-Type', 'application/json')
    jsondata = json.dumps(payload).encode('utf-8')
    req.add_header('Content-Length', len(jsondata))
    
    start = time.time()
    with urllib.request.urlopen(req, jsondata) as response:
        end = time.time()
        if response.status == 200:
            content = response.read()
            print(f"✅ Success! Received audio ({len(content)} bytes) in {end-start:.2f}s")
            # Save it
            with open("test_output.wav", "wb") as f:
                f.write(content)
            print("Saved to test_output.wav")
        else:
            print(f"❌ Failed: {response.status}")

except urllib.error.HTTPError as e:
    print(f"❌ HTTP Error: {e.code}")
    print(e.read().decode())
except urllib.error.URLError as e:
    print(f"❌ URL Error: {e.reason}")
except Exception as e:
    print(f"❌ Error: {e}")
