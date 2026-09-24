"""
Composite generation for 'But They Built Roads: Colonial Transport Networks and
Path Dependency in Africa' (Berrada, Development and Change, forthcoming).

Builds the continental composite from the NetLogo slime-mould simulation outputs.

Method
------
Each simulation exports a 300x300 PNG at 95 per cent exploration. A pixel counts
as mould where all three RGB channels exceed 200. Each run's white mask is
dilated by a circular structuring element of radius `pixel_tolerance` before
counting, so that runs whose corridors differ by a few pixels still agree. A
pixel is rendered pure white in the composite where at least
`threshold_percentage` of runs agree after dilation; elsewhere the mean of all
runs is shown.

Spatial tolerance
-----------------
5 pixels at this resolution is roughly a 100 km corridor either side of the
predicted route. That width is deliberate: it is the margin within which a real
road could be routed around a mountain or a lake while still following the
predicted corridor.

Published figures
-----------------
    create_composite(pixel_tolerance=5, threshold_percentage=50)  -> theta50.png
    create_composite(pixel_tolerance=5, threshold_percentage=80)  -> theta80.png

Run from the directory holding the 350 simulation PNGs
(<Cluster>_run<N>_95percent_tick-<T>.png, seven clusters of fifty runs).

Requires: numpy, pillow, scipy
"""

import re
import numpy as np
from pathlib import Path
from PIL import Image
from scipy.ndimage import binary_dilation

def find_cluster_files(cluster_name):
    """
    Find all simulation files for a specific cluster.
    """
    pattern = f"{cluster_name}_run*_95percent_tick-*.png"
    files = list(Path('.').glob(pattern))
    
    if not files:
        pattern = f"{cluster_name}_run*_tick-*.png"
        files = list(Path('.').glob(pattern))
    
    if not files:
        return []
    
    # Sort files by run number
    def extract_run_number(filename):
        match = re.search(r'_run(\d+)_', filename.name)
        return int(match.group(1)) if match else 0
    
    files.sort(key=extract_run_number)
    return [str(f) for f in files]

def find_all_clusters():
    """
    Find all unique cluster names by looking for simulation files.
    """
    all_files = list(Path('.').glob("*_run*_95percent_tick-*.png"))
    if not all_files:
        all_files = list(Path('.').glob("*_run*_tick-*.png"))
    
    cluster_names = set()
    for file in all_files:
        parts = file.stem.split('_run')
        if len(parts) >= 2:
            cluster_name = parts[0]
            if cluster_name != "Historical":  # Skip Historical
                cluster_names.add(cluster_name)
    
    return sorted(cluster_names)

def create_composite(pixel_tolerance=5, threshold_percentage=50):
    """
    Create a single composite with custom pixel spatial tolerance from all simulations.
    
    Parameters:
    pixel_tolerance: Number of pixels for spatial tolerance (1-15 recommended)
    threshold_percentage: Percentage of images that need to agree for a pixel to be white
    """
    print(f"🚀 CREATING COMPOSITE WITH {pixel_tolerance}-PIXEL TOLERANCE")
    print("="*50)
    
    # Get all simulation files
    all_sim_files = []
    cluster_names = find_all_clusters()
    
    for cluster_name in cluster_names:
        cluster_files = find_cluster_files(cluster_name)
        all_sim_files.extend(cluster_files)
    
    if not all_sim_files:
        print("❌ No simulation files found!")
        return None
    
    print(f"📊 Found {len(all_sim_files)} simulation files")
    print(f"🎯 Using {threshold_percentage}% threshold with 5-pixel tolerance")
    
    # Load first image to get dimensions
    first_image = Image.open(all_sim_files[0]).convert('RGB')
    width, height = first_image.size
    num_images = len(all_sim_files)
    threshold_count = int(num_images * threshold_percentage / 100)
    
    print(f"📐 Image dimensions: {width}x{height}")
    print(f"🔢 Threshold: {threshold_count}/{num_images} images ({threshold_percentage}%)")
    print(f"🔄 Spatial tolerance: ±{pixel_tolerance} pixels (~±{pixel_tolerance*20}km)")
    
    # Initialize counters and accumulators
    white_count_tolerance = np.zeros((height, width), dtype=np.int32)
    accumulated = np.zeros((height, width, 3), dtype=np.float64)
    
    # Define white threshold
    WHITE_THRESHOLD = 200  # RGB values above this are considered "white"
    
    # Create custom pixel circular dilation structure
    y, x = np.ogrid[-pixel_tolerance:pixel_tolerance+1, -pixel_tolerance:pixel_tolerance+1]
    disk_custom = x*x + y*y <= pixel_tolerance*pixel_tolerance
    
    print(f"\n🔄 Processing images with {pixel_tolerance}-pixel spatial dilation...")
    
    for i, image_path in enumerate(all_sim_files):
        if i % 25 == 0:  # Progress indicator
            print(f"    Processing image {i+1}/{num_images}")
        
        try:
            img = Image.open(image_path).convert('RGB')
            img_array = np.array(img, dtype=np.float64)
            
            # Identify white pixels
            is_white = np.all(img_array > WHITE_THRESHOLD, axis=2)
            
            # Apply custom pixel spatial tolerance using binary dilation
            is_white_tolerance = binary_dilation(is_white, structure=disk_custom)
            
            # Count the spatially-dilated white pixels
            white_count_tolerance += is_white_tolerance.astype(np.int32)
            
            # Accumulate for grayscale blending
            accumulated += img_array / num_images
            
        except Exception as e:
            print(f"  ❌ Error processing {image_path}: {e}")
            continue
    
    # Create final image
    final_array = np.clip(accumulated, 0, 255).astype(np.uint8)
    
    # Apply threshold logic: if pixel had tolerance consensus, make it pure white
    consensus_white_tolerance = white_count_tolerance >= threshold_count
    final_array[consensus_white_tolerance] = [255, 255, 255]  # Pure white
    
    # Create and save result
    result_image = Image.fromarray(final_array, 'RGB')
    output_path = f"composite{pixel_tolerance}pix.png"
    result_image.save(output_path)
    
    # Summary
    white_pixels = np.sum(consensus_white_tolerance)
    total_pixels = height * width
    white_percentage = (white_pixels / total_pixels) * 100
    
    print(f"\n✅ COMPOSITE CREATED: {output_path}")
    print(f"📊 RESULTS:")
    print(f"   • {white_pixels:,} pixels met {threshold_percentage}% consensus")
    print(f"   • {white_percentage:.2f}% of image is white (roads)")
    print(f"   • {pixel_tolerance}-pixel tolerance captured alignment variations")
    print(f"   • Remaining pixels use grayscale blending")
    
    return result_image


if __name__ == "__main__":
    # the two thresholds reported in the article
    create_composite(pixel_tolerance=5, threshold_percentage=50)
    create_composite(pixel_tolerance=5, threshold_percentage=80)
