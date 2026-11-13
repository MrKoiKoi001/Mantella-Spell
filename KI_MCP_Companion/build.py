"""Builds the companion mod for Skyrim and (on request) puts it into the game.

    python build.py              compile the scripts and build the plugin into .\\build
    python build.py --install    build, then copy everything into the game folder and activate the plugin

What it needs on this PC:
- The Creation Kit from Steam (for PapyrusCompiler.exe and the script sources of the game)
- SKSE with its script sources in <game>\\Data\\Scripts\\Source
- For the quests: KI_MCP_Gefaehrte.dll in .\\SKSE\\Plugins. It is built on GitHub from the plugin repository
  (the fork of mantella-vanilla-dialogue). Without it everything else still works
- Spriggit, which turns the text files in Spriggit_data into the .esp. It is downloaded once into .\\tools

Everything that is printed also goes to build\\build_log.txt.
Only the Python standard library is used.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import struct
import urllib.request
import wave
import zipfile
from typing import List, Optional

PLUGIN_NAME = "KI_MCP_Gefaehrte.esp"
OWN_SCRIPTS = ["KI_MCP_Gefaehrte_Loop", "KI_MCP_Gefaehrte_PlayerAlias", "KI_MCP_Gefaehrte_Native"]
# The SKSE plugin of this mod. It reads what scripts cannot get at (the open quests)
NATIVE_PLUGIN = "KI_MCP_Gefaehrte.dll"
# The DLL calls functions of this script to raise its events, so the game needs the compiled script as well
HTTP_SCRIPT = "SKSE_HTTP"
HTTP_PLUGIN = "SKSE_HTTP.dll"
FLAGS_FILE = "TESV_Papyrus_Flags.flg"
# For the command say: the companion server puts the sound of what the companion says into
# Data\Sound\Voice\<plugin>\<voice>\<one of these names>.wav. The names are made by the game:
# the first 10 letters of the quest, the first 15 of the topic, the ID of the response, its number
VOICE_LINE_FILES = ["KI_MCP_Say_KI_MCP_SayOne_00000805_1.wav", "KI_MCP_Say_KI_MCP_SayTwo_00000807_1.wav"]
# The voices that get a folder (one name per line, lines with # in front are notes)
VOICE_FOLDERS_FILE = "voice_folders.txt"
# The group "Users" of Windows, by its fixed number, so that it works in every language of Windows
WINDOWS_USERS_GROUP = "*S-1-5-32-545"
# The game only lets characters speak the lines of a quest that starts with the game if a file Data\Seq\<plugin>.seq
# names that quest (otherwise only after saving and loading once). The file is a row of quest IDs, four bytes each,
# as they stand in the plugin: the local ID with the number of masters of the plugin in front (one master: Skyrim.esm)
SEQ_QUEST_IDS = [0x01000803]
SILENCE_SAMPLE_RATE = 22050
SILENCE_SECONDS = 0.2

DEFAULT_CREATION_KIT_FOLDER = r"F:\SteamLibrary\steamapps\common\skyrim"
DEFAULT_GAME_FOLDER = r"F:\SteamLibrary\steamapps\common\SkyrimVR"
# Folder below %LOCALAPPDATA% in which the game keeps plugins.txt
DEFAULT_APPDATA_NAME = "Skyrim VR"

SPRIGGIT_VERSION = "0.41.0"
SPRIGGIT_URL = "https://github.com/Mutagen-Modding/Spriggit/releases/download/" + SPRIGGIT_VERSION + "/SpriggitCLI.zip"
SPRIGGIT_EXE = "Spriggit.CLI.exe"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_FOLDER = os.path.dirname(HERE)
OWN_SOURCE_FOLDER = os.path.join(HERE, "Scripts", "Source")
OWN_PLUGINS_FOLDER = os.path.join(HERE, "SKSE", "Plugins")
MANTELLA_SOURCE_FOLDER = os.path.join(REPO_FOLDER, "Scripts", "Source")
SPRIGGIT_DATA_FOLDER = os.path.join(HERE, "Spriggit_data")
BUILD_FOLDER = os.path.join(HERE, "build")
BUILD_SCRIPTS_FOLDER = os.path.join(BUILD_FOLDER, "Scripts")
GAME_SOURCE_FOLDER = os.path.join(BUILD_FOLDER, "game_source")
TOOLS_FOLDER = os.path.join(HERE, "tools")
LOG_FILE = os.path.join(BUILD_FOLDER, "build_log.txt")

log_handle = None


class BuildError(Exception):
    pass


def say(text: str = "") -> None:
    print(text, flush=True)
    if log_handle is not None:
        log_handle.write(text + "\n")
        log_handle.flush()


def run(command: List[str], working_folder: str) -> int:
    say("> " + subprocess.list2cmdline(command))
    try:
        finished = subprocess.run(command, cwd=working_folder, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  universal_newlines=True, errors="replace")
    except OSError as error:
        raise BuildError("Could not start " + command[0] + ": " + str(error))
    for line in finished.stdout.splitlines():
        say("    " + line)
    return finished.returncode


def find_file(folder: str, file_name: str, max_depth: int = 4) -> Optional[str]:
    """Looks for a file below a folder (the name is compared without regard to case)"""
    if not os.path.isdir(folder):
        return None
    start_depth = folder.rstrip("\\/").count(os.sep)
    for current, folders, files in os.walk(folder):
        for candidate in files:
            if candidate.lower() == file_name.lower():
                return os.path.join(current, candidate)
        if current.count(os.sep) - start_depth >= max_depth:
            del folders[:]
    return None


# ------------------------------------------------------------------ scripts

def find_compiler(creation_kit_folder: str) -> str:
    compiler = find_file(creation_kit_folder, "PapyrusCompiler.exe")
    if compiler is None:
        raise BuildError("PapyrusCompiler.exe not found below " + creation_kit_folder
                         + ". Is the Creation Kit installed there? Otherwise pass --creation-kit <folder>.")
    return compiler


def extract_archive(archive: str, target_folder: str) -> None:
    os.makedirs(target_folder, exist_ok=True)
    say("Unpacking " + archive + " into " + target_folder)
    if archive.lower().endswith(".zip"):
        with zipfile.ZipFile(archive) as opened:
            opened.extractall(target_folder)
        return
    # A .rar (old Creation Kit): Python cannot read it. Windows brings tar, and 7-Zip can do it as well
    attempts = [["tar", "-xf", archive, "-C", target_folder]]
    for program_folder in [os.environ.get("ProgramFiles", ""), os.environ.get("ProgramFiles(x86)", "")]:
        seven_zip = os.path.join(program_folder, "7-Zip", "7z.exe")
        if program_folder != "" and os.path.isfile(seven_zip):
            attempts.append([seven_zip, "x", "-y", "-o" + target_folder, archive])
    for attempt in attempts:
        try:
            if run(attempt, target_folder) == 0:
                return
        except BuildError as error:
            say(str(error))
    raise BuildError("Could not unpack " + archive + ". Please unpack it by hand into " + target_folder + " and start again.")


def find_game_sources(creation_kit_folder: str, game_folder: str) -> str:
    """Returns the folder with the script sources of the game itself (recognised by Debug.psc)"""
    places = [
        os.path.join(game_folder, "Data", "Scripts", "Source"),
        os.path.join(game_folder, "Data", "Source", "Scripts"),
        os.path.join(creation_kit_folder, "Data", "Scripts", "Source"),
        os.path.join(creation_kit_folder, "Data", "Source", "Scripts"),
    ]
    for place in places:
        if os.path.isfile(os.path.join(place, "Debug.psc")):
            return place
    found = find_file(GAME_SOURCE_FOLDER, "Debug.psc")
    if found is not None:
        return os.path.dirname(found)

    for archive_name in ["Scripts.zip", "Scripts.rar"]:
        archive = find_file(creation_kit_folder, archive_name, max_depth=2)
        if archive is not None:
            extract_archive(archive, GAME_SOURCE_FOLDER)
            found = find_file(GAME_SOURCE_FOLDER, "Debug.psc")
            if found is not None:
                return os.path.dirname(found)
            raise BuildError("Unpacked " + archive + " but there is no Debug.psc in it.")
    raise BuildError("The script sources of the game were not found: neither unpacked nor as Scripts.zip or Scripts.rar below "
                     + creation_kit_folder + ".")


def find_skse_sources(game_folder: str) -> str:
    place = os.path.join(game_folder, "Data", "Scripts", "Source")
    # StringUtil.psc only comes with SKSE
    if not os.path.isfile(os.path.join(place, "StringUtil.psc")):
        raise BuildError("The script sources of SKSE were not found in " + place
                         + ". They are in the SKSE download in Data\\Scripts\\Source.")
    return place


def compile_scripts(creation_kit_folder: str, game_folder: str) -> List[str]:
    compiler = find_compiler(creation_kit_folder)
    game_sources = find_game_sources(creation_kit_folder, game_folder)
    skse_sources = find_skse_sources(game_folder)
    say("Compiler:      " + compiler)
    say("Game sources:  " + game_sources)
    say("SKSE sources:  " + skse_sources)

    # The first folder that has a script wins, so SKSE's versions have to come before the ones of the game
    import_folders = [OWN_SOURCE_FOLDER, MANTELLA_SOURCE_FOLDER, skse_sources, game_sources]
    os.makedirs(BUILD_SCRIPTS_FOLDER, exist_ok=True)

    compiled_files = []
    for script in OWN_SCRIPTS + [HTTP_SCRIPT]:
        compiled_file = os.path.join(BUILD_SCRIPTS_FOLDER, script + ".pex")
        if os.path.isfile(compiled_file):
            os.remove(compiled_file)
        say()
        say("Compiling " + script)
        return_code = run([compiler, script + ".psc", "-f=" + FLAGS_FILE, "-i=" + ";".join(import_folders),
                           "-o=" + BUILD_SCRIPTS_FOLDER], os.path.dirname(compiler))
        if return_code != 0 or not os.path.isfile(compiled_file):
            raise BuildError("Compiling " + script + " failed (see the lines above).")
        compiled_files.append(compiled_file)
    return compiled_files


# ------------------------------------------------------------------- plugin

def get_spriggit() -> str:
    spriggit_folder = os.path.join(TOOLS_FOLDER, "spriggit")
    spriggit = find_file(spriggit_folder, SPRIGGIT_EXE)
    if spriggit is not None:
        return spriggit

    os.makedirs(spriggit_folder, exist_ok=True)
    archive = os.path.join(TOOLS_FOLDER, "SpriggitCLI.zip")
    say("Downloading Spriggit " + SPRIGGIT_VERSION + " from " + SPRIGGIT_URL)
    try:
        with urllib.request.urlopen(SPRIGGIT_URL, timeout=300) as response, open(archive, "wb") as target:
            shutil.copyfileobj(response, target)
    except Exception as error:
        raise BuildError("Download failed (" + str(error) + "). Please download the file by hand and unpack it into " + spriggit_folder + ".")
    with zipfile.ZipFile(archive) as opened:
        opened.extractall(spriggit_folder)
    os.remove(archive)

    spriggit = find_file(spriggit_folder, SPRIGGIT_EXE)
    if spriggit is None:
        raise BuildError(SPRIGGIT_EXE + " is not in the download. Look into " + spriggit_folder + ".")
    return spriggit


def build_plugin() -> str:
    spriggit = get_spriggit()
    plugin = os.path.join(BUILD_FOLDER, PLUGIN_NAME)
    if os.path.isfile(plugin):
        os.remove(plugin)
    say()
    say("Building " + PLUGIN_NAME)
    return_code = run([spriggit, "convert-to-plugin", "--InputPath", SPRIGGIT_DATA_FOLDER, "--OutputPath", plugin],
                      os.path.dirname(spriggit))
    if return_code != 0 or not os.path.isfile(plugin):
        raise BuildError("Spriggit could not build the plugin (see the lines above).")
    return plugin


# ------------------------------------------------------------------ install

def copy_file(source: str, target_folder: str) -> None:
    os.makedirs(target_folder, exist_ok=True)
    target = os.path.join(target_folder, os.path.basename(source))
    try:
        shutil.copyfile(source, target)
    except PermissionError:
        raise BuildError("No permission to write " + target + ". Is the game still running? "
                         "Otherwise start this from a terminal that runs as administrator.")
    say("Copied  " + target)


def activate_plugin(plugins_file: str) -> None:
    """Skyrim only loads plugins that are listed in plugins.txt with a star in front"""
    wanted_line = "*" + PLUGIN_NAME
    lines = []
    if os.path.isfile(plugins_file):
        with open(plugins_file, "r", encoding="latin-1") as opened:
            lines = opened.read().splitlines()
    for line in lines:
        if line.strip().lower() == wanted_line.lower():
            say("Already active in " + plugins_file)
            return
    lines = [line for line in lines if line.strip().lower() != PLUGIN_NAME.lower()]
    lines.append(wanted_line)
    os.makedirs(os.path.dirname(plugins_file), exist_ok=True)
    with open(plugins_file, "w", encoding="latin-1", newline="\r\n") as opened:
        opened.write("\n".join(lines) + "\n")
    say("Activated in " + plugins_file)


def check_address_library(game_folder: str, skse_plugins_folder: str) -> None:
    """The DLL only loads in Skyrim VR if the VR Address Library (a file version-....csv) is in SKSE\\Plugins"""
    if len(glob.glob(os.path.join(skse_plugins_folder, "version-*.csv"))) > 0:
        return
    for current, folders, files in os.walk(game_folder):
        if current.count(os.sep) - game_folder.rstrip("\\/").count(os.sep) >= 3:
            del folders[:]
        for candidate in files:
            if candidate.lower().startswith("version-") and candidate.lower().endswith(".csv"):
                say("The Address Library was in the wrong place: " + os.path.join(current, candidate))
                copy_file(os.path.join(current, candidate), skse_plugins_folder)
                return
    say("WARNING: No Address Library (version-....csv) in " + skse_plugins_folder + ". Without it " + HTTP_PLUGIN + " does not load.")


def read_voice_folders() -> List[str]:
    names = []
    with open(os.path.join(HERE, VOICE_FOLDERS_FILE), "r", encoding="utf-8") as opened:
        for line in opened.read().splitlines():
            if line.strip() != "" and not line.strip().startswith("#"):
                names.append(line.strip())
    return names


def write_silence(file: str) -> None:
    with wave.open(file, "wb") as opened:
        opened.setnchannels(1)
        opened.setsampwidth(2)
        opened.setframerate(SILENCE_SAMPLE_RATE)
        opened.writeframes(b"\x00\x00" * int(SILENCE_SAMPLE_RATE * SILENCE_SECONDS))


def install_voice_folders(data_folder: str) -> None:
    """Prepares the folders for the command say. The game only finds sound files that were there when it started,
    so every voice gets its folder with silent files, which the companion server overwrites later.
    The server does not run as administrator, so the normal users of this PC get the right to write there"""
    voice_root = os.path.join(data_folder, "Sound", "Voice", PLUGIN_NAME)
    created = 0
    try:
        for voice in read_voice_folders():
            voice_folder = os.path.join(voice_root, voice)
            os.makedirs(voice_folder, exist_ok=True)
            for file_name in VOICE_LINE_FILES:
                file = os.path.join(voice_folder, file_name)
                if not os.path.isfile(file):
                    write_silence(file)
                    created += 1
    except OSError as error:
        raise BuildError("Could not prepare the voice folders in " + voice_root + ": " + str(error))
    say("Voice folders for 'say' are in " + voice_root + " (" + str(created) + " new silent files)")
    if os.name == "nt":
        if run(["icacls", voice_root, "/grant", WINDOWS_USERS_GROUP + ":(OI)(CI)M", "/T", "/Q"], voice_root) != 0:
            say("WARNING: Could not give the users of this PC the right to write into " + voice_root
                + ". Then the companion server can only make the companion speak if it runs as administrator.")


def install_seq_file(data_folder: str) -> None:
    seq_folder = os.path.join(data_folder, "Seq")
    seq_file = os.path.join(seq_folder, os.path.splitext(PLUGIN_NAME)[0] + ".seq")
    try:
        os.makedirs(seq_folder, exist_ok=True)
        with open(seq_file, "wb") as opened:
            for quest_id in SEQ_QUEST_IDS:
                opened.write(struct.pack("<I", quest_id))
    except OSError as error:
        raise BuildError("Could not write " + seq_file + ": " + str(error))
    say("Written " + seq_file)


def install(game_folder: str, plugins_file: str, compiled_files: List[str], plugin: str) -> None:
    data_folder = os.path.join(game_folder, "Data")
    if not os.path.isdir(data_folder):
        raise BuildError("No Data folder in " + game_folder + ". Pass the game folder with --game <folder>.")
    skse_plugins_folder = os.path.join(data_folder, "SKSE", "Plugins")
    say()
    say("Installing into " + game_folder)
    copy_file(plugin, data_folder)
    for compiled_file in compiled_files:
        copy_file(compiled_file, os.path.join(data_folder, "Scripts"))
    copy_file(os.path.join(REPO_FOLDER, "SKSE", "Plugins", HTTP_PLUGIN), skse_plugins_folder)
    native_plugin = os.path.join(OWN_PLUGINS_FOLDER, NATIVE_PLUGIN)
    if os.path.isfile(native_plugin):
        copy_file(native_plugin, skse_plugins_folder)
    else:
        say("NOTE: " + native_plugin + " is missing. The mod works without it, but the AI does not get the quests. "
            "Download the DLL from the last successful build of the plugin repository on GitHub (Actions, Artifacts) and put it there.")
    check_address_library(game_folder, skse_plugins_folder)
    install_voice_folders(data_folder)
    install_seq_file(data_folder)
    activate_plugin(plugins_file)
    if len(glob.glob(os.path.join(game_folder, "skse*_loader.exe"))) == 0:
        say("WARNING: No SKSE loader (skse..._loader.exe) in " + game_folder + ". The mod needs SKSE.")


def main() -> int:
    global log_handle
    parser = argparse.ArgumentParser(description="Builds the companion mod (scripts and plugin)")
    parser.add_argument("--install", action="store_true", help="Copy the result into the game folder and activate the plugin")
    parser.add_argument("--creation-kit", default=DEFAULT_CREATION_KIT_FOLDER, help="Folder of the Creation Kit (default: %(default)s)")
    parser.add_argument("--game", default=DEFAULT_GAME_FOLDER, help="Folder of the game (default: %(default)s)")
    parser.add_argument("--plugins-file", default=os.path.join(os.environ.get("LOCALAPPDATA", ""), DEFAULT_APPDATA_NAME, "plugins.txt"),
                        help="The plugins.txt of the game (default: %(default)s)")
    arguments = parser.parse_args()

    os.makedirs(BUILD_FOLDER, exist_ok=True)
    log_handle = open(LOG_FILE, "w", encoding="utf-8")
    try:
        compiled_files = compile_scripts(arguments.creation_kit, arguments.game)
        plugin = build_plugin()
        if arguments.install:
            install(arguments.game, arguments.plugins_file, compiled_files, plugin)
        say()
        if arguments.install:
            say("DONE. Built and installed. Start the game through the SKSE loader.")
        else:
            say("DONE. The result is in " + BUILD_FOLDER + ". To put it into the game: python build.py --install")
        return 0
    except BuildError as error:
        say()
        say("FAILED: " + str(error))
        return 1
    finally:
        log_handle.close()


if __name__ == "__main__":
    sys.exit(main())
