import os
from PIL import Image

def remove_white_bg_smart(path):
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    visited = set()
    queue = [(0,0), (width-1, 0), (0, height-1), (width-1, height-1)]
    
    while queue:
        x, y = queue.pop(0)
        if (x, y) in visited: continue
        visited.add((x, y))
        
        if x < 0 or x >= width or y < 0 or y >= height: continue
        
        r, g, b, a = pixels[x, y]
        
        # If it's a grayscale pixel (background transition)
        if abs(r - g) < 20 and abs(g - b) < 20 and abs(r - b) < 20:
            intensity = (r + g + b) // 3
            if intensity > 20:
                # Set underlying color to black, alpha inversely proportional to white intensity
                pixels[x, y] = (0, 0, 0, 255 - intensity)
                
                queue.append((x+1, y))
                queue.append((x-1, y))
                queue.append((x, y+1))
                queue.append((x, y-1))
                
                queue.append((x+1, y+1))
                queue.append((x-1, y-1))
                queue.append((x+1, y-1))
                queue.append((x-1, y+1))

    img.save(path)

output_dir = r"c:\Users\autav\OneDrive\Documents\CLI\stitch_flutter_music_ui_redesign"
out_512 = os.path.join(output_dir, "r_music_icono_full_new.png")
out_60 = os.path.join(output_dir, "r_music_icono_60_new.png")

remove_white_bg_smart(out_512)
remove_white_bg_smart(out_60)
print("Done")
