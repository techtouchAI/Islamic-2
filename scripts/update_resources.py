import json
import base64
import os
import io
from PIL import Image

def update_resources():
    json_path = "assets/data/content.json"
    if not os.path.exists(json_path):
        return

    with open(json_path, 'r') as f:
        data = json.load(f)

    settings = data.get('settings', {})

    # 1. Handle Launcher Icon
    b64_logo = settings.get('custom_logo_base64')
    if b64_logo and b64_logo.startswith('data:image'):
        try:
            header, encoded = b64_logo.split(',', 1)
            img_data = base64.b64decode(encoded)
            img = Image.open(io.BytesIO(img_data))
            if img.mode != 'RGBA':
                img = img.convert('RGBA')

            sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
            for d, size in sizes.items():
                icon_path = f"android/app/src/main/res/mipmap-{d}/ic_launcher.png"
                os.makedirs(os.path.dirname(icon_path), exist_ok=True)
                resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
                resized_img.save(icon_path, "PNG")
            print("Updated launcher icons.")
        except Exception as e:
            print(f"Error updating icons: {e}")

    # 2. Handle Adhan Audio
    adhan_settings = settings.get('adhan', {})
    b64_audio = adhan_settings.get('adhan_base64')
    if b64_audio and b64_audio.startswith('data:audio'):
        try:
            header, encoded = b64_audio.split(',', 1)
            audio_data = base64.b64decode(encoded)

            # For Android Notifications
            raw_dir = "android/app/src/main/res/raw"
            os.makedirs(raw_dir, exist_ok=True)
            with open(os.path.join(raw_dir, "adhan.mp3"), 'wb') as f:
                f.write(audio_data)

            # For Flutter Assets
            assets_audio_dir = "assets/audio"
            os.makedirs(assets_audio_dir, exist_ok=True)
            with open(os.path.join(assets_audio_dir, "adhan.mp3"), 'wb') as f:
                f.write(audio_data)

            print("Updated Adhan audio resource in both raw and assets.")
        except Exception as e:
            print(f"Error updating audio: {e}")

if __name__ == "__main__":
    update_resources()
