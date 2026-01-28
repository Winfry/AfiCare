#!/usr/bin/env python3
"""
Generate PNG icons from SVG for PWA and favicon
Requires: pip install cairosvg pillow
"""

import os
import sys

def generate_pngs():
    """Generate PNG icons at various sizes"""

    # Try cairosvg first (best quality)
    try:
        import cairosvg
        from PIL import Image
        import io

        print("Using cairosvg for high-quality conversion...")

        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_svg = os.path.join(script_dir, "icon.svg")

        sizes = [16, 32, 48, 72, 96, 128, 144, 152, 192, 384, 512]

        for size in sizes:
            output_path = os.path.join(script_dir, f"icon-{size}x{size}.png")
            cairosvg.svg2png(
                url=icon_svg,
                write_to=output_path,
                output_width=size,
                output_height=size
            )
            print(f"  Created: icon-{size}x{size}.png")

        # Create favicon.ico (multi-size)
        favicon_sizes = [16, 32, 48]
        images = []
        for size in favicon_sizes:
            png_data = cairosvg.svg2png(url=icon_svg, output_width=size, output_height=size)
            img = Image.open(io.BytesIO(png_data))
            images.append(img)

        favicon_path = os.path.join(script_dir, "favicon.ico")
        images[0].save(favicon_path, format='ICO', sizes=[(s, s) for s in favicon_sizes])
        print(f"  Created: favicon.ico")

        # Create Apple touch icon
        apple_path = os.path.join(script_dir, "apple-touch-icon.png")
        cairosvg.svg2png(url=icon_svg, write_to=apple_path, output_width=180, output_height=180)
        print(f"  Created: apple-touch-icon.png")

        print("\nAll PNG icons generated successfully!")
        return True

    except ImportError:
        print("cairosvg not found, trying alternative method...")

    # Fallback: Create simple colored icons using PIL
    try:
        from PIL import Image, ImageDraw

        print("Using PIL to create simple icons...")

        script_dir = os.path.dirname(os.path.abspath(__file__))
        sizes = [16, 32, 48, 72, 96, 128, 144, 152, 192, 384, 512]

        # Colors
        green = (46, 125, 50)  # #2E7D32
        white = (255, 255, 255)
        light_green = (129, 199, 132)  # #81C784

        for size in sizes:
            # Create image
            img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)

            # Draw circle background
            margin = int(size * 0.05)
            draw.ellipse([margin, margin, size-margin, size-margin], fill=green)

            # Draw inner circle (heart area)
            inner_margin = int(size * 0.15)
            draw.ellipse([inner_margin, inner_margin, size-inner_margin, size-inner_margin],
                        fill=white)

            # Draw medical cross
            cross_width = int(size * 0.12)
            cross_height = int(size * 0.35)
            center = size // 2

            # Vertical bar
            draw.rectangle([
                center - cross_width//2,
                center - cross_height//2,
                center + cross_width//2,
                center + cross_height//2
            ], fill=green)

            # Horizontal bar
            draw.rectangle([
                center - cross_height//2,
                center - cross_width//2,
                center + cross_height//2,
                center + cross_width//2
            ], fill=green)

            # Save
            output_path = os.path.join(script_dir, f"icon-{size}x{size}.png")
            img.save(output_path, 'PNG')
            print(f"  Created: icon-{size}x{size}.png")

        # Create favicon
        favicon_path = os.path.join(script_dir, "favicon.ico")
        img_16 = Image.open(os.path.join(script_dir, "icon-16x16.png"))
        img_32 = Image.open(os.path.join(script_dir, "icon-32x32.png"))
        img_48 = Image.open(os.path.join(script_dir, "icon-48x48.png"))
        img_16.save(favicon_path, format='ICO', sizes=[(16, 16), (32, 32), (48, 48)])
        print(f"  Created: favicon.ico")

        # Apple touch icon
        apple_img = Image.new('RGBA', (180, 180), (0, 0, 0, 0))
        draw = ImageDraw.Draw(apple_img)
        draw.ellipse([9, 9, 171, 171], fill=green)
        draw.ellipse([27, 27, 153, 153], fill=white)
        center = 90
        cross_w, cross_h = 22, 63
        draw.rectangle([center-cross_w//2, center-cross_h//2, center+cross_w//2, center+cross_h//2], fill=green)
        draw.rectangle([center-cross_h//2, center-cross_w//2, center+cross_h//2, center+cross_w//2], fill=green)
        apple_path = os.path.join(script_dir, "apple-touch-icon.png")
        apple_img.save(apple_path, 'PNG')
        print(f"  Created: apple-touch-icon.png")

        print("\nAll PNG icons generated successfully!")
        return True

    except ImportError:
        print("ERROR: PIL/Pillow not installed. Run: pip install pillow")
        return False

if __name__ == "__main__":
    generate_pngs()
