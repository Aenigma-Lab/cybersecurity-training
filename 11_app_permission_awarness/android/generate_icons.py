#!/usr/bin/env python3
"""
Generate professional Android app launcher icons with blue gradient and shield-lock design
"""

from PIL import Image, ImageDraw
import os

# Colors for gradient
BLUE_DARK = (21, 101, 192, 255)  # #1565C0
BLUE_LIGHT = (66, 165, 245, 255)  # #42A5F5
WHITE = (255, 255, 255, 255)

# Icon sizes for different screen densities
ICONS = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192
}

def create_gradient_background(size):
    """Create a gradient background from dark blue to light blue"""
    img = Image.new('RGBA', (size, size), BLUE_DARK)
    
    # Create gradient by interpolating colors
    pixels = img.load()
    for y in range(size):
        # Calculate gradient factor (0 to 1)
        factor = y / size
        # Interpolate between dark blue and light blue
        r = int(BLUE_DARK[0] + factor * (BLUE_LIGHT[0] - BLUE_DARK[0]))
        g = int(BLUE_DARK[1] + factor * (BLUE_LIGHT[1] - BLUE_DARK[1]))
        b = int(BLUE_DARK[2] + factor * (BLUE_LIGHT[2] - BLUE_DARK[2]))
        for x in range(size):
            pixels[x, y] = (r, g, b, 255)
    
    return img

def draw_shield(draw, center_x, center_y, size):
    """Draw a shield shape in the center"""
    shield_width = int(size * 0.55)
    shield_height = int(size * 0.65)
    left = center_x - shield_width // 2
    top = center_y - shield_height // 2
    right = left + shield_width
    bottom = top + shield_height
    
    # Shield points
    shield_points = [
        (left + shield_width * 0.5, top),  # Top center
        (right, top + shield_height * 0.2),  # Top right
        (right, top + shield_height * 0.55),  # Middle right
        (left + shield_width * 0.5, bottom),  # Bottom center
        (left, top + shield_height * 0.55),  # Middle left
        (left, top + shield_height * 0.2),  # Top left
    ]
    
    # Draw filled shield with slight shadow effect
    draw.polygon(shield_points, fill=WHITE)
    
    return shield_points

def draw_lock(draw, center_x, center_y, size):
    """Draw a lock symbol inside the shield"""
    lock_body_width = int(size * 0.22)
    lock_body_height = int(size * 0.16)
    lock_shackle_width = int(size * 0.14)
    lock_shackle_height = int(size * 0.14)
    
    body_left = center_x - lock_body_width // 2
    body_top = center_y + int(size * 0.08)
    body_right = body_left + lock_body_width
    body_bottom = body_top + lock_body_height
    
    shackle_left = center_x - lock_shackle_width // 2
    shackle_top = body_top - lock_shackle_height + 4
    shackle_right = shackle_left + lock_shackle_width
    shackle_bottom = body_top + 2
    
    # Draw shackle (arch)
    shackle_thickness = max(2, int(size * 0.03))
    # Draw left side of shackle
    draw.rectangle(
        [shackle_left, shackle_top + shackle_thickness, shackle_left + shackle_thickness, shackle_bottom],
        fill=BLUE_DARK
    )
    # Draw right side of shackle
    draw.rectangle(
        [shackle_right - shackle_thickness, shackle_top + shackle_thickness, shackle_right, shackle_bottom],
        fill=BLUE_DARK
    )
    # Draw top of shackle
    draw.rectangle(
        [shackle_left + shackle_thickness, shackle_top, shackle_right - shackle_thickness, shackle_top + shackle_thickness],
        fill=BLUE_DARK
    )
    
    # Draw lock body
    draw.rectangle(
        [body_left, body_top, body_right, body_bottom],
        fill=BLUE_DARK
    )
    
    # Draw keyhole
    keyhole_size = max(3, int(size * 0.04))
    draw.ellipse(
        [center_x - keyhole_size//2, center_y - int(size * 0.02), 
         center_x + keyhole_size//2, center_y + int(size * 0.04)],
        fill=WHITE
    )

def create_icon(size):
    """Create a professional launcher icon with gradient background and shield-lock"""
    # Create gradient background
    img = create_gradient_background(size)
    draw = ImageDraw.Draw(img)
    
    # Draw shield in center
    center_x = size // 2
    center_y = size // 2
    shield_points = draw_shield(draw, center_x, center_y, size)
    
    # Draw lock icon on shield
    draw_lock(draw, center_x, center_y, size)
    
    return img

def main():
    base_path = '/home/alfa/Desktop/android/app/src/main/res'
    
    for density, size in ICONS.items():
        # Create mipmap directory if it doesn't exist
        mipmap_dir = os.path.join(base_path, f'mipmap-{density}')
        os.makedirs(mipmap_dir, exist_ok=True)
        
        # Generate icons
        icon = create_icon(size)
        
        # Save ic_launcher.png
        icon_path = os.path.join(mipmap_dir, 'ic_launcher.png')
        icon.save(icon_path, 'PNG')
        print(f'Created {icon_path} ({size}x{size})')
        
        # Save ic_launcher_round.png
        round_icon_path = os.path.join(mipmap_dir, 'ic_launcher_round.png')
        icon.save(round_icon_path, 'PNG')
        print(f'Created {round_icon_path} ({size}x{size})')
    
    print('\nAll professional icons generated successfully!')

if __name__ == '__main__':
    main()
