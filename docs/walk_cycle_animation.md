# Indie-Style 6-Frame Walk Cycle Animation

This guide creates a complete, looping walk cycle using 6 keyframes optimized for indie games. The animation alternates between left and right foot contacts for natural, seamless looping.

## Frame 1: Left Contact - Impact
**Action**: Left foot strikes ground with full body weight transfer
- Left leg extended forward, foot planted firmly
- Body shows compression from impact - slight crouch
- Right foot lifting off ground behind
- Arms: Right arm forward, left arm back (opposing motion)
- **Key pose** - Hold this frame longer (200ms)

## Frame 2: Left Push - Compression
**Action**: Body settles and prepares to spring forward
- Left leg compressed, absorbing weight
- Right leg swings up, knee bent high
- Body at lowest point in cycle
- Torso leans slightly forward with momentum
- Arms: Right arm pulls back to neutral, left arm swings toward forward position

## Frame 3: Mid-Stride - Suspension
**Action**: Peak energy release, both feet off ground
- Right leg swinging forward at highest arc
- Left leg pushing off, beginning to lift
- Body at highest point, slight forward lean
- Maximum arm extension in opposing directions
- **Key pose** - Emphasizes stylized floating moment

## Frame 4: Right Contact - Impact
**Action**: Right foot strikes ground (mirror of Frame 1)
- Right leg extended forward, foot planted firmly
- Body shows compression from impact
- Left foot lifting off ground behind
- Arms: Left arm forward, right arm back
- **Key pose** - Hold this frame longer (200ms)

## Frame 5: Right Push - Compression
**Action**: Body settles and prepares to spring forward (mirror of Frame 2)
- Right leg compressed, absorbing weight
- Left leg swings up, knee bent high
- Body at lowest point in cycle
- Torso leans slightly forward
- Arms: Left arm pulls back to neutral, right arm swings toward forward position

## Frame 6: Mid-Stride - Suspension
**Action**: Peak energy release, preparing for left contact (mirror of Frame 3)
- Left leg swinging forward at highest arc
- Right leg pushing off, beginning to lift
- Body at highest point, loops back to Frame 1
- Maximum arm extension
- **Key pose** - Creates anticipation for loop restart

**Animation Philosophy**: Emphasize the **contact** and **suspension** moments. These are your money shots - the impact frames (1,4) show weight and power, while suspension frames (3,6) show grace and style.

## Aseprite Implementation Guide

### Layer Organization
Create separate layers for better control and editing:
- **Background** - Static background elements (optional)
- **Body** - Main torso and head
- **Arms** - Both arms on same layer for simplicity
- **Legs** - Both legs on same layer
- **Details** - Hair, clothing details, accessories

### Frame Setup
1. Set your sprite to 6 frames total
2. Frame timing for indie feel:
   - Frames 1,4 (contacts): 200ms - emphasize impact
   - Frames 2,5 (compression): 100ms - quick transition
   - Frames 3,6 (suspension): 250ms - stylized hang time
3. Use onion skinning (previous/next frame visibility) to maintain consistency between frames

### Animation Tags
Create an animation tag for organization:
1. Go to **Frame → Tags**
2. Create tag covering frames 1-6
3. Name it "walk_cycle"
4. Set direction to "Forward" for continuous looping

### Workflow Tips
- **Work in passes**: Complete all 6 frames for one body part before moving to the next
- **Mirror workflow**: Frames 4-6 mirror frames 1-3, saving time on poses
- **Use reference layer**: Set frame 1 as reference when working on other frames
- **Preview frequently**: Use spacebar to play animation and check flow
- **Export settings**: Use "Save As" → GIF to test your animation loop

### Advanced Features to Explore
- **Cel linking**: Link identical elements across frames to save time
- **Animation curves**: Adjust frame timing for more natural motion
- **Tilemap mode**: Useful if character will walk across repeating ground tiles
