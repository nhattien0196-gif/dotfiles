#!/usr/bin/env fish
set wallpaper_dir "$HOME/.config/ml4w/wallpapers"
set output "$HOME/.config/rofi/random-wallpaper.rasi"
set images (find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))
if test (count $images) -eq 0
    echo "Khong tim thay wallpaper"
    exit 1
end
set image $images[(random 1 (count $images))]
printf '* { current-image: url("%s", width); }\n' "$image" > "$output"
echo "Da chon: $image"
