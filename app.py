from flask import Flask, request, send_file
from flask_cors import CORS
from gtts import gTTS
import io

app = Flask(__name__)
CORS(app)

@app.route('/speak', methods=['POST'])
def speak():
    text = request.form.get('text')
    language = request.form.get('language', 'en')
    slow = request.form.get('slow', 'false') == 'true'

    if not text:
        return {"status": "error", "message": "No text provided"}, 400

    # Generate MP3 audio using gTTS and send it as a file
    tts = gTTS(text=text, lang=language, slow=slow)
    mp3_fp = io.BytesIO()
    tts.write_to_fp(mp3_fp)
    mp3_fp.seek(0)

    return send_file(
        mp3_fp,
        mimetype="audio/mpeg",
        as_attachment=True,
        download_name="speech.mp3"
    )

@app.route('/health')
def health():
    return {"status": "ok"}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
