# avo_toolkit

## Set of tools and libraries for various Avo projects

To use, clone this repo to `/Library/Application Support/Adobe/CEP/extensions` and open it via `Window > Extensions` in AE

To run in debug mode:

- Win: regedit > HKEY_CURRENT_USER/Software/Adobe/CSXS.10, then add a new entry PlayerDebugMode of type "string" with the value of "1".
- Mac: In the terminal, type: `defaults write com.adobe.CSXS.10 PlayerDebugMode 1` (The plist is also located at /Users/<username>/Library/Preferences/com.adobe.CSXS.10.plist)
