from fastapi import FastAPI, File, Form, UploadFile, HTTPException, Query, BackgroundTasks
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import cv2
import easyocr 
import numpy as np
import os
import uuid
import shutil
import logging
from typing import List, Optional, Dict, Any
import time
from gtts import gTTS
import io

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Multifunctional API",
    description="API for image processing (text removal/extraction) and text-to-speech conversion",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Set this to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure folders
UPLOAD_FOLDER = 'uploads'
RESULT_FOLDER = r'C:\Users\eaz99\Desktop\Programming App\VS Code\Dart Flutter Projects\First project\myfirst\assets\images'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(RESULT_FOLDER, exist_ok=True)

# Initialize EasyOCR Reader (lazy initialization)
reader = None
current_langs = []

# Cleanup interval in seconds
def cleanup_old_files(folder: str, max_age_seconds: int = 3600):
    current_time = time.time()
    for filename in os.listdir(folder):
        file_path = os.path.join(folder, filename)
        if os.path.isfile(file_path):
            file_age = current_time - os.path.getmtime(file_path)
            if file_age > max_age_seconds:
                try:
                    os.remove(file_path)
                    logger.info(f"Removed old file: {file_path}")
                except Exception as e:
                    logger.error(f"Error deleting {file_path}: {e}")

def get_reader(languages=['en','ar']):
    """Get or initialize the EasyOCR reader with specified languages"""
    global reader, current_langs
    
    # Convert to sorted tuple for consistent comparison
    langs_tuple = tuple(sorted(languages))
    
    # Check if we need to initialize a new reader (singleton pattern)
    if reader is None or set(current_langs) != set(languages):
        logger.info(f"Initializing EasyOCR reader with languages: {languages}")
        reader = easyocr.Reader(languages, gpu=False)
        current_langs = languages
    
    return reader

def remove_text_from_image(image_path: str, languages: List[str] = ['en'], inpaint_radius: int = 3) -> str:
    """
    Remove text from an image using EasyOCR and inpainting
    
    Returns: Path to the processed image
    """
    # Load image
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image from {image_path}")
    
    # Get or initialize EasyOCR Reader
    reader = get_reader(languages)
    
    # Run OCR
    results = reader.readtext(img)
    
    # Create mask
    mask = np.zeros(img.shape[:2], dtype=np.uint8)
    
    # Loop through all detected texts
    for (bbox, text, prob) in results:
        # Unpack the bounding box
        (top_left, top_right, bottom_right, bottom_left) = bbox
        pts = np.array(bbox, dtype=np.int32)
        cv2.fillPoly(mask, [pts], 255)  # Fill detected text area on mask
    
    # Inpaint to remove text
    inpainted = cv2.inpaint(img, mask, inpaintRadius=inpaint_radius, flags=cv2.INPAINT_TELEA)
    
    # Generate output path
    filename = os.path.basename(image_path)
    name, ext = os.path.splitext(filename)
    output_path = os.path.join(RESULT_FOLDER, f"{name}_cleaned{ext}")
    
    # Save the result
    cv2.imwrite(output_path, inpainted)
    
    return output_path

def extract_text_from_image(image_path: str, languages: List[str] = ['en']) -> Dict[str, Any]:
    """
    Extract text from an image using EasyOCR
    
    Returns: Dictionary with extracted text, full text, and detailed results
    """
    # Get or initialize EasyOCR Reader
    reader = get_reader(languages)
    
    # Read the image
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image from {image_path}")
    
    # Run OCR
    results = reader.readtext(img)
    
    # Extract text
    extracted_text = [text for _, text, _ in results]
    
    return {
        "text": extracted_text, 
        "full_text": " ".join(extracted_text),
        "detailed_results": [
            {
                "text": text,
                "confidence": float(prob),
                "bounding_box": bbox
            } for bbox, text, prob in results
        ]
    }

@app.post("/remove-text", summary="Remove text from an image")
async def remove_text_api(
    background_tasks: BackgroundTasks,
    image: UploadFile = File(..., description="Image file to process"),
    languages: str = Form("en", description="Comma-separated list of language codes"),
    inpaint_radius: int = Form(3, description="Radius for inpainting algorithm")
):
    """
    Remove text from an uploaded image.
    
    - **image**: The image file to process
    - **languages**: Comma-separated list of language codes (default: 'en')
    - **inpaint_radius**: Radius for inpainting algorithm (default: 3)
    
    Returns the processed image with text removed.
    """
    try:
        # Parse language list
        language_list = languages.split(',')
        
        # Generate a unique filename and save the uploaded file
        filename = image.filename
        unique_filename = f"{uuid.uuid4()}_{filename}"
        file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
        
        # Save the uploaded file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        
        # Process the image
        try:
            logger.info(f"Processing image {filename} for text removal")
            result_path = remove_text_from_image(file_path, language_list, inpaint_radius)
            
            # Schedule cleanup of old files
            # background_tasks.add_task(cleanup_old_files, RESULT_FOLDER)
            
            # Return the processed image
            return FileResponse(
                result_path,
                media_type="image/jpeg",
                filename=os.path.basename(result_path)
            )
        finally:
            # Clean up the uploaded file
            if os.path.exists(file_path):
                os.remove(file_path)
    
    except Exception as e:
        logger.error(f"Error in remove_text_api: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/extract-text", summary="Extract text from an image")
async def extract_text_api(
    image: UploadFile = File(..., description="Image file to process"),
    languages: str = Form("en", description="Comma-separated list of language codes")
):
    """
    Extract text from an uploaded image.
    
    - **image**: The image file to process
    - **languages**: Comma-separated list of language codes (default: 'en')
    
    Returns the extracted text.
    """
    try:
        # Parse language list
        language_list = languages.split(',')
        
        # Generate a unique filename and save the uploaded file
        filename = image.filename
        unique_filename = f"{uuid.uuid4()}_{filename}"
        file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
        
        # Save the uploaded file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        
        # Process the image
        try:
            logger.info(f"Processing image {filename} for text extraction")
            result = extract_text_from_image(file_path, language_list)
            return result
        
        finally:
            # Clean up the uploaded file
            if os.path.exists(file_path):
                os.remove(file_path)
    
    except Exception as e:
        logger.error(f"Error in extract_text_api: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/speak", summary="Convert text to speech")
async def speak(
    text: str = Form(..., description="Text to convert to speech"),
    language: str = Form("en", description="Language code for speech synthesis"),
    slow: bool = Form(False, description="Whether to speak slowly")
):
    """
    Convert text to speech using gTTS.
    
    - **text**: The text to convert to speech
    - **language**: Language code (default: 'en')
    - **slow**: Whether to speak slowly (default: False)
    
    Returns an MP3 audio file.
    """
    if not text:
        raise HTTPException(status_code=400, detail="No text provided")
    
    try:
        # Generate MP3 audio using gTTS
        tts = gTTS(text=text, lang=language, slow=slow)
        mp3_fp = io.BytesIO()
        tts.write_to_fp(mp3_fp)
        mp3_fp.seek(0)
        
        return StreamingResponse(
            mp3_fp,
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": "attachment; filename=speech.mp3"
            }
        )
    except Exception as e:
        logger.error(f"Error in speak endpoint: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health", summary="Health check endpoint")
async def health_check():
    """
    Check if the API is running.
    
    Returns a status message.
    """
    return {
        "status": "ok", 
        "services": ["text_removal", "text_extraction", "text_to_speech"],
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
