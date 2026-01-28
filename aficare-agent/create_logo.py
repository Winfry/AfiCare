"""
AfiCare MediLink Logo Generator
Creates professional logos using Python graphics libraries
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import Circle, Rectangle, FancyBboxPatch
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import io
import base64

def create_logo_style_1():
    """
    Modern Medical Cross with MediLink Text
    Clean, professional healthcare logo
    """
    fig, ax = plt.subplots(1, 1, figsize=(12, 6))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 6)
    ax.axis('off')
    
    # Background
    bg = Rectangle((0, 0), 12, 6, facecolor='white', edgecolor='none')
    ax.add_patch(bg)
    
    # Medical cross - modern style
    cross_color = '#2E8B57'  # Sea green
    
    # Vertical bar of cross
    vertical = FancyBboxPatch(
        (1.5, 1), 0.8, 4,
        boxstyle="round,pad=0.1",
        facecolor=cross_color,
        edgecolor='none'
    )
    ax.add_patch(vertical)
    
    # Horizontal bar of cross
    horizontal = FancyBboxPatch(
        (0.7, 2.6), 2.4, 0.8,
        boxstyle="round,pad=0.1",
        facecolor=cross_color,
        edgecolor='none'
    )
    ax.add_patch(horizontal)
    
    # Add small heart in center
    heart_x, heart_y = 1.9, 3
    heart = Circle((heart_x, heart_y), 0.15, facecolor='white', edgecolor='none')
    ax.add_patch(heart)
    
    # Add connecting dots (representing network/links)
    dot_color = '#4CAF50'
    dots = [
        (3.8, 4.5), (4.2, 3.8), (4.6, 3.2), (5.0, 2.6),
        (3.8, 1.5), (4.2, 2.2), (4.6, 2.8)
    ]
    
    for x, y in dots:
        dot = Circle((x, y), 0.08, facecolor=dot_color, edgecolor='none')
        ax.add_patch(dot)
    
    # Connect dots with lines
    line_color = '#81C784'
    for i in range(len(dots)-1):
        x1, y1 = dots[i]
        x2, y2 = dots[i+1]
        ax.plot([x1, x2], [y1, y2], color=line_color, linewidth=2, alpha=0.7)
    
    # Main text - AfiCare
    ax.text(6.5, 4.2, 'AfiCare', fontsize=36, fontweight='bold', 
            color='#2E8B57', fontfamily='sans-serif')
    
    # Subtitle - MediLink
    ax.text(6.5, 3.4, 'MediLink', fontsize=24, fontweight='normal',
            color='#4CAF50', fontfamily='sans-serif')
    
    # Tagline
    ax.text(6.5, 2.8, 'Your Health Records, Your Control', fontsize=12,
            color='#666666', fontfamily='sans-serif', style='italic')
    
    # Small medical symbols as text
    ax.text(6.3, 1.8, 'HOSP', fontsize=12, color='#4CAF50', fontweight='bold')
    ax.text(7.0, 1.8, 'MED', fontsize=12, color='#4CAF50', fontweight='bold')
    ax.text(7.7, 1.8, 'CARE', fontsize=12, color='#4CAF50', fontweight='bold')
    ax.text(8.4, 1.8, 'TECH', fontsize=12, color='#4CAF50', fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('logo_style_1.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    plt.close()
    
    print("[OK] Logo Style 1 created: logo_style_1.png")

def create_logo_style_2():
    """
    Circular Badge Style Logo
    Professional medical badge with African colors
    """
    fig, ax = plt.subplots(1, 1, figsize=(10, 10))
    ax.set_xlim(-5, 5)
    ax.set_ylim(-5, 5)
    ax.axis('off')
    
    # Outer circle - African sunset colors
    outer_circle = Circle((0, 0), 4.5, facecolor='#FF6B35', edgecolor='#E55A2B', linewidth=3)
    ax.add_patch(outer_circle)
    
    # Inner circle - clean white
    inner_circle = Circle((0, 0), 3.8, facecolor='white', edgecolor='none')
    ax.add_patch(inner_circle)
    
    # Medical cross in center
    cross_color = '#2E8B57'
    
    # Vertical bar
    vertical = Rectangle((-0.4, -2), 0.8, 4, facecolor=cross_color, edgecolor='none')
    ax.add_patch(vertical)
    
    # Horizontal bar
    horizontal = Rectangle((-2, -0.4), 4, 0.8, facecolor=cross_color, edgecolor='none')
    ax.add_patch(horizontal)
    
    # Add small circles around the cross (representing connectivity)
    circle_positions = [
        (2.5, 2.5), (-2.5, 2.5), (-2.5, -2.5), (2.5, -2.5),
        (3, 0), (0, 3), (-3, 0), (0, -3)
    ]
    
    for x, y in circle_positions:
        small_circle = Circle((x, y), 0.2, facecolor='#4CAF50', edgecolor='white', linewidth=2)
        ax.add_patch(small_circle)
    
    # Text around the circle
    ax.text(0, -4.2, 'AfiCare MediLink', fontsize=20, fontweight='bold',
            ha='center', va='center', color='#2E8B57')
    
    plt.tight_layout()
    plt.savefig('logo_style_2.png', dpi=300, bbox_inches='tight',
                facecolor='white')
    plt.close()
    
    print("[OK] Logo Style 2 created: logo_style_2.png")

def create_logo_style_3():
    """
    Minimalist Tech Style
    Clean, modern logo for digital platforms
    """
    fig, ax = plt.subplots(1, 1, figsize=(14, 4))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 4)
    ax.axis('off')
    
    # Background gradient effect using rectangles
    colors = ['#E8F5E8', '#F0F8F0', '#F8FBF8']
    for i, color in enumerate(colors):
        rect = Rectangle((0, i*1.33), 14, 1.33, facecolor=color, edgecolor='none', alpha=0.3)
        ax.add_patch(rect)
    
    # Modern geometric medical symbol
    # DNA helix style
    helix_color = '#2E8B57'
    
    # Left strand
    x1 = np.linspace(0.5, 2.5, 50)
    y1 = 2 + 0.8 * np.sin(4 * np.pi * (x1 - 0.5) / 2)
    ax.plot(x1, y1, color=helix_color, linewidth=6, alpha=0.8)
    
    # Right strand
    y2 = 2 + 0.8 * np.sin(4 * np.pi * (x1 - 0.5) / 2 + np.pi)
    ax.plot(x1, y2, color='#4CAF50', linewidth=6, alpha=0.8)
    
    # Connecting lines
    for i in range(0, len(x1), 8):
        ax.plot([x1[i], x1[i]], [y1[i], y2[i]], color='#81C784', linewidth=2, alpha=0.6)
    
    # Main text with modern font
    ax.text(4, 2.8, 'AfiCare', fontsize=42, fontweight='300',
            color='#2E8B57', fontfamily='sans-serif')
    
    ax.text(4, 2.0, 'MediLink', fontsize=28, fontweight='400',
            color='#4CAF50', fontfamily='sans-serif')
    
    # Subtitle with tech feel
    ax.text(4, 1.4, 'AI-Powered Healthcare Records', fontsize=14,
            color='#666666', fontfamily='monospace')
    
    # Tech elements - small squares representing data
    tech_color = '#81C784'
    squares = [(11, 3.2), (11.4, 3.2), (11.8, 3.2), (12.2, 3.2),
               (11, 2.8), (11.4, 2.8), (11.8, 2.8), (12.2, 2.8),
               (11, 2.4), (11.4, 2.4), (11.8, 2.4), (12.2, 2.4)]
    
    for x, y in squares:
        square = Rectangle((x, y), 0.2, 0.2, facecolor=tech_color, 
                          edgecolor='none', alpha=0.7)
        ax.add_patch(square)
    
    plt.tight_layout()
    plt.savefig('logo_style_3.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    
    print("✅ Logo Style 3 created: logo_style_3.png")

def create_logo_style_4():
    """
    African-Inspired Logo
    Incorporates African design elements with medical symbols
    """
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.axis('off')
    
    # African sunset background
    sunset_colors = ['#FF6B35', '#F7931E', '#FFD23F']
    
    # Create sunset effect
    for i, color in enumerate(sunset_colors):
        circle = Circle((2, 6), 1.5 - i*0.3, facecolor=color, alpha=0.6, edgecolor='none')
        ax.add_patch(circle)
    
    # African pattern border
    pattern_color = '#8B4513'
    
    # Traditional African geometric patterns
    triangles = [
        [(0.2, 0.2), (0.6, 0.2), (0.4, 0.8)],
        [(0.8, 0.2), (1.2, 0.2), (1.0, 0.8)],
        [(11.0, 0.2), (11.4, 0.2), (11.2, 0.8)],
        [(11.6, 0.2), (12.0, 0.2), (11.8, 0.8)]
    ]
    
    for triangle in triangles:
        tri = patches.Polygon(triangle, facecolor=pattern_color, alpha=0.4)
        ax.add_patch(tri)
    
    # Central medical symbol - stylized as African mask
    mask_color = '#2E8B57'
    
    # Mask outline
    mask = patches.Ellipse((6, 4.5), 3, 4, facecolor=mask_color, alpha=0.8)
    ax.add_patch(mask)
    
    # Eyes (representing vision/insight)
    left_eye = patches.Ellipse((5.3, 5), 0.4, 0.6, facecolor='white')
    right_eye = patches.Ellipse((6.7, 5), 0.4, 0.6, facecolor='white')
    ax.add_patch(left_eye)
    ax.add_patch(right_eye)
    
    # Medical cross in center
    cross_v = Rectangle((5.8, 3.5), 0.4, 2, facecolor='white')
    cross_h = Rectangle((5.0, 4.3), 2, 0.4, facecolor='white')
    ax.add_patch(cross_v)
    ax.add_patch(cross_h)
    
    # Text with African-inspired styling
    ax.text(6, 2.5, 'AfiCare', fontsize=36, fontweight='bold',
            ha='center', color='#8B4513', fontfamily='serif')
    
    ax.text(6, 1.8, 'MediLink', fontsize=24, fontweight='normal',
            ha='center', color='#2E8B57', fontfamily='serif')
    
    ax.text(6, 1.2, 'Healthcare for Africa', fontsize=14,
            ha='center', color='#666666', fontfamily='sans-serif', style='italic')
    
    plt.tight_layout()
    plt.savefig('logo_style_4.png', dpi=300, bbox_inches='tight',
                facecolor='#FFF8DC', edgecolor='none')
    plt.close()
    
    print("✅ Logo Style 4 created: logo_style_4.png")

def create_favicon():
    """
    Create a simple favicon (16x16 and 32x32)
    """
    fig, ax = plt.subplots(1, 1, figsize=(2, 2))
    ax.set_xlim(0, 2)
    ax.set_ylim(0, 2)
    ax.axis('off')
    
    # Simple medical cross
    cross_color = '#2E8B57'
    
    # Vertical bar
    vertical = Rectangle((0.8, 0.2), 0.4, 1.6, facecolor=cross_color)
    ax.add_patch(vertical)
    
    # Horizontal bar
    horizontal = Rectangle((0.2, 0.8), 1.6, 0.4, facecolor=cross_color)
    ax.add_patch(horizontal)
    
    # Small heart in center
    heart = Circle((1, 1), 0.1, facecolor='white')
    ax.add_patch(heart)
    
    plt.tight_layout()
    plt.savefig('favicon.png', dpi=150, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    
    print("✅ Favicon created: favicon.png")

def create_app_icon():
    """
    Create mobile app icon (512x512)
    """
    fig, ax = plt.subplots(1, 1, figsize=(8, 8))
    ax.set_xlim(-4, 4)
    ax.set_ylim(-4, 4)
    ax.axis('off')
    
    # Rounded square background
    bg = FancyBboxPatch(
        (-3.8, -3.8), 7.6, 7.6,
        boxstyle="round,pad=0.3",
        facecolor='#2E8B57',
        edgecolor='none'
    )
    ax.add_patch(bg)
    
    # Inner circle
    inner = Circle((0, 0), 2.8, facecolor='white', alpha=0.9)
    ax.add_patch(inner)
    
    # Medical cross
    cross_v = FancyBboxPatch(
        (-0.4, -2), 0.8, 4,
        boxstyle="round,pad=0.05",
        facecolor='#2E8B57'
    )
    ax.add_patch(cross_v)
    
    cross_h = FancyBboxPatch(
        (-2, -0.4), 4, 0.8,
        boxstyle="round,pad=0.05",
        facecolor='#2E8B57'
    )
    ax.add_patch(cross_h)
    
    # Small connecting dots
    dots = [(1.5, 1.5), (-1.5, 1.5), (-1.5, -1.5), (1.5, -1.5)]
    for x, y in dots:
        dot = Circle((x, y), 0.15, facecolor='#4CAF50')
        ax.add_patch(dot)
    
    # "ML" text for MediLink
    ax.text(0, -3.2, 'ML', fontsize=24, fontweight='bold',
            ha='center', va='center', color='white')
    
    plt.tight_layout()
    plt.savefig('app_icon.png', dpi=300, bbox_inches='tight',
                facecolor='white')
    plt.close()
    
    print("✅ App Icon created: app_icon.png")

def create_letterhead_logo():
    """
    Create horizontal logo for letterheads and documents
    """
    fig, ax = plt.subplots(1, 1, figsize=(16, 3))
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 3)
    ax.axis('off')
    
    # Medical symbol on left
    cross_color = '#2E8B57'
    
    # Stylized medical caduceus
    # Staff
    ax.plot([1, 1], [0.5, 2.5], color=cross_color, linewidth=8)
    
    # Wings
    wing_left = patches.Ellipse((0.7, 2.3), 0.6, 0.3, facecolor='#4CAF50', alpha=0.7)
    wing_right = patches.Ellipse((1.3, 2.3), 0.6, 0.3, facecolor='#4CAF50', alpha=0.7)
    ax.add_patch(wing_left)
    ax.add_patch(wing_right)
    
    # Snakes (simplified as curves)
    snake1_x = np.linspace(0.7, 1.3, 20)
    snake1_y = 1.5 + 0.3 * np.sin(8 * np.pi * (snake1_x - 0.7) / 0.6)
    ax.plot(snake1_x, snake1_y, color='#81C784', linewidth=4)
    
    snake2_x = np.linspace(0.7, 1.3, 20)
    snake2_y = 1.0 + 0.3 * np.sin(8 * np.pi * (snake2_x - 0.7) / 0.6 + np.pi)
    ax.plot(snake2_x, snake2_y, color='#81C784', linewidth=4)
    
    # Main text
    ax.text(3, 2.0, 'AfiCare MediLink', fontsize=32, fontweight='bold',
            color='#2E8B57', fontfamily='sans-serif', va='center')
    
    # Tagline
    ax.text(3, 1.3, 'AI-Powered Patient Records for African Healthcare', 
            fontsize=14, color='#666666', fontfamily='sans-serif', va='center')
    
    # Contact info placeholder
    ax.text(3, 0.7, 'www.aficare-medilink.org  •  info@aficare.org  •  +254-XXX-XXXXXX',
            fontsize=10, color='#999999', fontfamily='sans-serif', va='center')
    
    # Right side - small text icons
    icons_x = [13.5, 14.0, 14.5, 15.0]
    icons = ['HOSP', 'MED', 'CARE', 'TECH']
    
    for x, icon in zip(icons_x, icons):
        ax.text(x, 1.5, icon, fontsize=10, ha='center', va='center', 
                color='#4CAF50', fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('letterhead_logo.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()
    
    print("✅ Letterhead Logo created: letterhead_logo.png")

def main():
    """Generate all logo variations"""
    print("[*] Creating AfiCare MediLink Logos...")
    print("=" * 50)

    try:
        # Create all logo styles
        create_logo_style_1()      # Modern medical cross
        create_logo_style_2()      # Circular badge
        create_logo_style_3()      # Minimalist tech
        create_logo_style_4()      # African-inspired
        create_favicon()           # Small icon
        create_app_icon()          # Mobile app icon
        create_letterhead_logo()   # Document header

        print("=" * 50)
        print("[+] All logos created successfully!")
        print("\nLogo Files Created:")
        print("+-- logo_style_1.png      (Modern Medical Cross)")
        print("+-- logo_style_2.png      (Circular Badge)")
        print("+-- logo_style_3.png      (Minimalist Tech)")
        print("+-- logo_style_4.png      (African-Inspired)")
        print("+-- favicon.png           (Website Icon)")
        print("+-- app_icon.png          (Mobile App Icon)")
        print("+-- letterhead_logo.png   (Document Header)")

        print("\nUsage Recommendations:")
        print("* Style 1: Main website header, presentations")
        print("* Style 2: Social media profile, badges")
        print("* Style 3: Tech platforms, GitHub, documentation")
        print("* Style 4: Marketing materials, African contexts")
        print("* Favicon: Browser tab icon")
        print("* App Icon: Mobile app stores")
        print("* Letterhead: Official documents, emails")

    except Exception as e:
        print(f"[X] Error creating logos: {str(e)}")
        print("[!] Make sure matplotlib is installed: pip install matplotlib")

if __name__ == "__main__":
    main()