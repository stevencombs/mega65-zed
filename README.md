# retroCombs MEGA65-ZED Environment for Mac

Welcome, retroCombians! This repository contains everything you need to turn the incredibly fast [Zed](https://zed.dev) text editor into a fully-featured, integrated development environment (IDE) for the MEGA65.

Whether you are pushing code to real MEGA65 hardware over Ethernet or testing on the go with the XEMU emulator, MEGA65-ZED streamlines your BASIC65 workflow.

## 🌟 Features

* **Zero-Friction Install:** Automatically downloads and installs the Zed Editor if you don't already have it!
* **Automated Toolchain Setup:** A single script downloads and configures `petcat` (for tokenizing) and `etherload` (for sending PRGs to hardware).
* **Emulator Integration:** Automatically links your existing XEMU (`xmega65`) installation so you can compile and launch directly from Zed.
* **1-Click Build Tasks:** Zed tasks to instantly compile and send your code to hardware or the emulator.
* **BASIC65 Snippets:** Over 40 built-in Zed snippets for MEGA65 PETSCII mnemonics (e.g., type `m65clr` to instantly insert `{clr}`).

## 🛠️ Prerequisites

* A Mac (Intel or Apple Silicon)
* *(Optional)* The `xmega65` emulator installed in your `Applications` folder if you wish to use the emulator build task.

## 🚀 Installation

1. **Download this repository:** Clone it via Git or download it as a ZIP file and extract it to a permanent location on your Mac (e.g., `~/Projects/mega65-zed`).
2. **Open your Terminal** and navigate to that folder.
3. **Make the installer executable** by running:
~~~bash
chmod +x mega65zed-install.sh
~~~
4. **Run the setup script:**
~~~bash
./mega65zed-install.sh
~~~
5. **Restart your Terminal** (or run `source ~/.zshrc`) to apply the new MEGA65 tools to your system path.

## 💻 How to Use in Zed

### Project vs. Global Settings

This folder contains a hidden folder called `.zed` (press `Cmd + Shift + .` in Finder to see it).

* **Local Mode:** If you open this specific `mega65-zed` folder in Zed, the tasks and snippets will work automatically.
* **Global Mode (Recommended):** To use these MEGA65 features in *any* folder on your Mac, copy the contents of `tasks.json` and `snippets.json` into your global Zed settings (`~/.config/zed/tasks.json` and `~/.config/zed/snippets.json`).

### Writing Code (Snippets)

While typing in a `.bas` or `.txt` file, type `m65` to see a full list of MEGA65 PETSCII mnemonics.
For example, type `m65clr` and press `Enter` to instantly insert `{clr}`.

### Compiling and Running (Tasks)

1. Write your BASIC65 code.
2. Open the Zed Command Palette (`Cmd + Shift + P`).
3. Type **"task: spawn"** and press `Enter`.
4. Select either **"MEGA65: Send to Hardware"** or **"MEGA65: Run in XEMU"**.
   Zed will automatically compile your active file to a `build.prg` file in the same directory and launch it!

---
### 🔗 Let's Connect!

Subscribe and follow for more MEGA65 and retro computing content:

* [retroCombs on YouTube](https://www.youtube.com/@retrocombs)
* [retroCombs Tech on YouTube](https://www.youtube.com/@retrocombs-tech)
* [The retroCombs Blog](https://www.retrocombs.com)
