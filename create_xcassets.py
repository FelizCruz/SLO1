import os
import json
import shutil

def create_xcassets():
    xcassets_dir = r"SlugterraMVP\Sources\Assets.xcassets"
    if not os.path.exists(xcassets_dir):
        os.makedirs(xcassets_dir)

    # Root Contents.json
    with open(os.path.join(xcassets_dir, "Contents.json"), "w") as f:
        json.dump({"info": {"version": 1, "author": "xcode"}}, f)

    resources_dir = r"SlugterraMVP\Sources\Resources"
    if not os.path.exists(resources_dir):
        print("Resources dir not found!")
        return

    images = [f for f in os.listdir(resources_dir) if f.endswith(".png")]

    for img in images:
        name = os.path.splitext(img)[0]
        img_dir = os.path.join(xcassets_dir, f"{name}.imageset")
        os.makedirs(img_dir, exist_ok=True)
        
        # Copy image
        shutil.copy(os.path.join(resources_dir, img), os.path.join(img_dir, img))
        
        # Contents.json for image
        img_contents = {
            "images": [
                {
                    "idiom": "universal",
                    "filename": img,
                    "scale": "1x"
                },
                {
                    "idiom": "universal",
                    "scale": "2x"
                },
                {
                    "idiom": "universal",
                    "scale": "3x"
                }
            ],
            "info": {
                "version": 1,
                "author": "xcode"
            }
        }
        with open(os.path.join(img_dir, "Contents.json"), "w") as f:
            json.dump(img_contents, f, indent=4)
        print(f"Created imageset for {name}")

if __name__ == '__main__':
    create_xcassets()
