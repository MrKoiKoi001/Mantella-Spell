Mantella 1.7.104 SKSE Plugin Fix (unofficial) - version 1.0.0
==============================================================

WHAT THIS IS
Mantella 0.14's four SKSE plugins (MantellaDialogue.dll, MantellaLauncher.dll,
MantellaSubtitles.dll and SKSE_HTTP.dll), rebuilt from their original
open-source code so they load on Skyrim Special Edition 1.7.104.

Skyrim 1.7.99 and newer changed the Address Library format, and SKSE 2.3.x
refuses the original builds with "must be recompiled for new address library".

Nothing about Mantella's features was changed. The plugins were rebuilt with
CommonLibSSE-NG 12.1.0, which supports the new format. The only source edits
are a few lines needed to compile with the newer library (listed in the
Source Code download).

REQUIREMENTS
- Skyrim Special Edition (Steam) 1.7.104
- SKSE64 2.3.1
- Address Library for SKSE Plugins (including the 1.7.104 file)
- Mantella 0.14

INSTALL
Install with your mod manager and let this mod overwrite Mantella.
  Vortex: set this mod to load after Mantella.
  MO2: place this mod below Mantella.

UNINSTALL
Disable or remove this mod. Mantella's original DLLs are used again.

COMPATIBILITY
- Tested on Steam 1.7.104 with SKSE 2.3.1.
- Not for Skyrim VR.
- On Skyrim 1.6.1170 or older you don't need this. Use Mantella's own DLLs.
- For Mantella 0.14 only. Remove this mod when Mantella releases an official
  update, because newer Mantella versions ship their own updated plugins.

SOURCE CODE
The complete source code and build instructions are in the "Source Code"
download on this mod's Nexus page (Files tab, Miscellaneous files).

LICENSES
See the Licenses folder next to this file. In short:
- Plugin code: MIT license (art-from-the-machine, Mika Stamm, Steven Wu,
  Leidtier).
- The DLLs include CommonLibSSE-NG 12.1.0, licensed GPL-3.0-or-later with a
  Modding Exception and a GPL-3.0 Linking Exception. If you share modified
  DLLs, you must also share their source code.
- Other included libraries use permissive licenses
  (see Licenses/THIRD-PARTY-NOTICES.txt).
- The uploader claims no rights to any of this. The uploader's own changes
  (build scripts and the small source edits) are dedicated to the public
  domain under CC0 1.0 (Licenses/UPLOADER-CC0.txt).

The rebuild and the source edits were made with AI assistance.

CREDITS
art-from-the-machine ........ Mantella, MantellaLauncher
Mika Stamm .................. MantellaDialogue (mantella-vanilla-dialogue)
Steven Wu ................... MantellaSubtitles (Mantella-Subtitles-Plugin-NG)
Leidtier .................... SKSE_HTTP
alandtse and contributors ... CommonLibSSE-NG

This is not an official Mantella release. Please don't report problems with
this fix to Mantella's author.
