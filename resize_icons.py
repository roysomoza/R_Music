import os
from PIL import Image

# Paths
v3_path = r"C:\Users\autav\.gemini\antigravity-ide\brain\f0c6c5ab-734a-426b-8963-19ddf9f3a325\recolored_r_icon_v3_1787783688405.jpg"
r_only_path = r"C:\Users\autav\.gemini\antigravity-ide\brain\f0c6c5ab-734a-426b-8963-19ddf9f3a325\r_only_icon_1787784070113.jpg"

output_dir = r"c:\Users\autav\OneDrive\Documents\CLI\stitch_flutter_music_ui_redesign"
out_512 = os.path.join(output_dir, "r_music_icono_full_new.png")
out_60 = os.path.join(output_dir, "r_music_icono_60_new.png")

# Resize V3 to 512x512
with Image.open(v3_path) as img:
    img_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    img_512.save(out_512)
    print(f"Saved 512x512 to {out_512}")

# Resize R_only to 60x60
with Image.open(r_only_path) as img:
    img_60 = img.resize((60, 60), Image.Resampling.LANCZOS)
    img_60.save(out_60)
    print(f"Saved 60x60 to {out_60}")
