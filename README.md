# Cursor Reticle

A cursor addon for **Azeroth Survivors**: circles, a dot or crosshair, your health and a spell's
cooldown, drawn around the cursor so you never lose it in a fight.

<table>
  <tr>
    <td align="center"><img src="screenshots/default_circle.png" alt="The main circle around the cursor"><br><sub>Main circle</sub></td>
    <td align="center"><img src="screenshots/health_circle.gif" alt="The health circle draining and changing color"><br><sub>Health circle, colored by health</sub></td>
    <td align="center"><img src="screenshots/health_shield_circle_text.gif" alt="The health circle with a shield and the health % text"><br><sub>Shield and health % text</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/cooldown_sweep.gif" alt="The cooldown sweep filling as a spell recharges"><br><sub>Cooldown sweep</sub></td>
    <td align="center"><img src="screenshots/cooldown_sweep_with_main_circle.gif" alt="The cooldown sweep with the main circle inside it"><br><sub>Sweep with the main circle</sub></td>
    <td align="center"><img src="screenshots/cooldown_sweep_with_health_circle.gif" alt="The cooldown sweep with the health circle inside it"><br><sub>Sweep with the health circle</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/crosshair.png" alt="A crosshair at the cursor"><br><sub>Crosshair</sub></td>
    <td align="center"><img src="screenshots/low_opacity_dot.png" alt="A large see-through dot at the cursor"><br><sub>See-through dot</sub></td>
    <td></td>
  </tr>
</table>

## Features

- **Main circle** around the cursor, with its own size, thickness, opacity, color and outline.
- **Center dot or crosshair**, with size, thickness, opacity and color, or colored by health.
- **Health circle** that fills with your health, in one color or green to red as health drops,
  with your absorb shield shown over the end of the fill.
- **Cooldown sweep** that fills as a chosen spell recharges. The main circle or the health
  circle can sit inside or outside it.
- **Low health warning** that recolors the circles, the dot or crosshair, or makes them pulse.
- **Text at the cursor**: health %, shield and seconds left on the tracked spell, in your
  choice of font.
- **Previews** for the health circle, cooldown sweep and low health warning, so you can
  set them up outside a run.
- **Saved cursors**: save your setups under a name, each shown with a small preview, switch
  between them, and share them with other players as a short code.

Every part can be turned on or off. Each tab of the options window can be reset to its
defaults on its own, or everything at once with **Reset all**.

## Installation

1. Download `CursorReticle.zip` from the [latest release](../../releases/latest). Take that
   zip, not the "Source code" downloads.
2. Install it:
   - **Windows / Linux:** extract the zip into `benilla-config/AddOns/` next to the game's
     executable, so you get `AddOns/CursorReticle/`.
   - **Browser:** in the game, open **Options → AddOns** and install the zip.
3. The addon loads the next time you enter the world.

## Usage

| Command | What it does |
|---|---|
| `/cr` or `/creticle` | Open or close the options window |
| `/cr on` / `/cr off` / `/cr toggle` | Turn the addon on or off |
| `/cr reset` | Reset every setting to its default |

The cooldown sweep's spell list shows the spells you've had in a run on your current class.
A spell stays in the list for later runs once you've had it.

## Options

Click a screenshot to see it full size.

<table>
  <tr>
    <td align="center"><a href="screenshots/01_settings_circle.png"><img src="screenshots/01_settings_circle.png" width="400" alt="The Circle tab"></a><br><sub>Circle</sub></td>
    <td align="center"><a href="screenshots/02_settings_health-circle.png"><img src="screenshots/02_settings_health-circle.png" width="400" alt="The Health circle tab"></a><br><sub>Health circle</sub></td>
  </tr>
  <tr>
    <td align="center"><a href="screenshots/03_settings_center.png"><img src="screenshots/03_settings_center.png" width="400" alt="The Center tab"></a><br><sub>Center</sub></td>
    <td align="center"><a href="screenshots/04_settings_low-health.png"><img src="screenshots/04_settings_low-health.png" width="400" alt="The Low health tab"></a><br><sub>Low health</sub></td>
  </tr>
  <tr>
    <td align="center"><a href="screenshots/05_settings_cooldown-sweep.png"><img src="screenshots/05_settings_cooldown-sweep.png" width="400" alt="The Cooldown sweep tab"></a><br><sub>Cooldown sweep</sub></td>
    <td align="center"><a href="screenshots/06_settings_text.png"><img src="screenshots/06_settings_text.png" width="400" alt="The Text tab"></a><br><sub>Text</sub></td>
  </tr>
  <tr>
    <td align="center"><a href="screenshots/07_settings_save.png"><img src="screenshots/07_settings_save.png" width="400" alt="The Save tab with saved cursors and their previews"></a><br><sub>Save</sub></td>
    <td></td>
  </tr>
</table>

## License

[MIT](LICENSE)
