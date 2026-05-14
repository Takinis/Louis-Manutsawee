# Project Overview: Louis Manutsawee (Don't Starve Together Mod)

## General Information
- **Name:** Louis Manutsawee
- **Author:** Sydney
- **Version:** 3.0
- **Type:** Don't Starve Together (DST) Character Mod
- **Description:** A "Second Creation" character mod featuring a custom character named Louis Manutsawee, complete with specialized Kenjutsu (sword techniques), an energy system (Mind Power), and varied customization options.
- **Dependencies:** Requires the "Glassic API" mod (workshop-2521851770).

## Key Features & Mechanics
- **Custom Character:** Louis Manutsawee with unique voice/strings, assets, and portraits.
- **Kenjutsu System:** A unique sword skill combat system utilizing "Mind Power" (energy points).
  - Features multiple sword techniques (e.g., Ichimonji, Flip, Thrust, Isshin, Heavenly Strike, Ryusen, Susanoo, Soryuha, Counter Attack).
  - Includes a cooldown system for balancing.
  - Supports an experience (EXP) growth multiplier for character/skill progression.
- **Mind Power System (󰀈):** Used to cast Kenjutsu. Regenerates over time or per hit with katanas.
- **Custom Weapons:** Various starting and craftable katanas such as Shinai, Raikiri, Yasha (Shirasaya), Sakakura (Koshirae), Hitokiri, Mortal Blade, Shusui, and Kage.
- **Dodge Mechanics:** Ability to dodge in the direction of the mouse click.
- **Aesthetic Customizations:**
  - Multiple hairstyles and idle animations.
  - Ability to wear eyeglasses and change hairstyles via hotkeys.
  - Wide variety of character skins and outfits (maid, miko, qipao, sailor, shinsengumi, yukata, etc.).

## Directory Structure & Assets
- **`modinfo.lua`**: Contains mod configuration, metadata, keybindings, and gameplay options.
- **`anim/`**: Packed animation files (`.zip`) for the character, weapons, hair, faces, and special effects.
- **`bigportraits/`**: Character portrait XML/TEX files for the character selection screen.
- **`scripts/`**: Lua scripts containing the core logic, prefabs, stategraphs, and UI elements.
- **`strings/`**: Dialogue and text translations.
- **`images/`**: UI icons and inventory graphics.
- **`postinit/`**: Hooks to inject custom code into existing DST functions or prefabs.

## Configuration Options (via modinfo.lua)
- **Language Support:** Built-in translations for English, Chinese (Simplified, Traditional, Cantonese), and various others (via Google Translate).
- **Gameplay Toggles:** 
  - Limiter ("is_tatsujin") toggle.
  - Starting Weapon selection.
  - Customizable hotkeys for all skills and actions.
  - Adjustable cooldowns, Mind Power regeneration, and EXP rates.

## Code Style & Conventions
- **Naming Conventions:**
  - **Variables and Fields:** Uses `snake_case` (e.g., `max_mindpower`, `regen_mindpower_rate`, `hit_cd`).
  - **Constants:** Uses `UPPER_SNAKE_CASE` (e.g., `SKILL_ID`, `SG_STATE`, `INPUT_COOLDOWN`).
  - **Functions and Classes:** Uses `PascalCase` or `CamelCase` for module-level functions, methods, and classes (e.g., `CalculateMaxLevel`, `LevelNotReached`, `Kenjutsuka`, `OnAttackOther`).
- **Formatting:** 
  - **Indentation:** Uses 4 spaces for indentation blocks.
- **Scoping & Structure:**
  - **Localization:** Heavy use of `local` variables to cache module requirements, internal arrays/tables, and helper functions (e.g., `local MakePlayerCharacter = require(...)`).
  - **DST Idioms:** Strictly follows Don't Starve Together modding standards, regularly manipulating `inst.components.*`, subscribing to events with `ListenForEvent` and `PushEvent`, and instantiating with `SpawnPrefab()`.
- **Hooking & Injection Style (postinit/):**
  - **Standard API Usage:** Relies on standard mod API injection functions such as `AddComponentPostInit`, `AddPrefabPostInit`, `AddStategraphPostInit`, `AddStategraphEvent`, and `AddStategraphState`.
  - **Method Overriding:** Uses a non-destructive functional wrapper approach. Existing component methods are cached locally (e.g., `local _GetAttacked = self.GetAttacked`) and overridden gracefully (`function self:GetAttacked(...)`). 
  - **Conditional Execution:** Overrides generally check for specific custom tags (e.g., `inst:HasTag("kenjutsuka")`) to ensure vanilla prefabs remain unaffected, calling the cached base method when conditions aren't met.
- **Comments:** Generally sparse; mostly brief, descriptive comments in English when documenting complex properties or hacks.