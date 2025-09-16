shader_type canvas_item;

// A uniform is a parameter you can control from your GDScript.
// We'll use this to control the "whiteness" of the flash.
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Get the original color of the sprite's pixel.
    vec4 original_color = texture(TEXTURE, UV);

    // Create the white color we want to flash to.
    vec4 white_color = vec4(1.0, 1.0, 1.0, original_color.a);

    // The mix() function blends two colors together.
    // When flash_modifier is 0, we get the original color.
    // When flash_modifier is 1, we get the white color.
    vec4 final_color = mix(original_color, white_color, flash_modifier);

    // Apply the final color to the sprite.
    COLOR = final_color;
}