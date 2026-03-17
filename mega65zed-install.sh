#!/bin/bash
# mega65zed-install.sh - retroCombs MEGA65-ZED Environment Setup for Mac

echo "================================================="
echo " retroCombs MEGA65-ZED Environment Setup for Mac"
echo " Version: 1.0.4"
echo "================================================="
echo "This script will install and configure the following tools:"
echo "  1. Zed Editor - The lightning-fast text editor (if not installed)."
echo "  2. etherload (from mega65-tools GitHub) - For sending PRG files to hardware."
echo "  3. petcat (from MEGA65 Filehost) - For tokenizing BASIC65 text files."
echo "  4. xmega65 (Symlink) - Connects your existing XEMU emulator to Zed."
echo "  5. Homebrew / 7zip (If required) - To extract the latest MEGA65 archives."
echo ""
echo "All tools will be safely isolated in: $HOME/.retrocombs-m65/bin"
echo "================================================="
echo ""

# 0. Check for and install Zed Editor
echo "Checking for Zed Editor..."
if [ ! -d "/Applications/Zed.app" ] && [ ! -d "$HOME/Applications/Zed.app" ] && ! command -v zed &> /dev/null; then
    echo "Zed Editor not found. Installing the latest version..."
    curl -f https://zed.dev/install.sh | sh
    echo "✅ Zed Editor installed successfully!"
else
    echo "✅ Zed Editor is already installed."
fi
echo ""

# 1. Setup the portable tools directory
M65_DIR="$HOME/.retrocombs-m65/bin"
echo "Creating tools directory at $M65_DIR..."
mkdir -p "$M65_DIR"

# 2. Fetch mega65-tools (etherload) from GitHub
echo "Fetching the latest mega65-tools for Mac from GitHub..."

# Try GitHub API first (checking recent releases, ignoring specific tags)
ASSET_URL=$(curl -s https://api.github.com/repos/MEGA65/mega65-tools/releases | grep -i "browser_download_url" | grep -iE "mac|darwin" | grep -iE "\.tar\.gz|\.zip|\.7z" | head -n 1 | cut -d '"' -f 4 | tr -d '[:space:]')

# Fallback to HTML scraping if API rate limit is hit
if [ -z "$ASSET_URL" ]; then
    echo "API empty. Trying direct HTML scrape to bypass rate limits..."
    RELEASE_PATH=$(curl -s https://github.com/MEGA65/mega65-tools/releases | grep -o 'href="[^"]*mac[^"]*\.\(zip\|tar\.gz\|7z\)"' | head -n 1 | cut -d '"' -f 2)
    if [ -n "$RELEASE_PATH" ]; then
        ASSET_URL="https://github.com$RELEASE_PATH"
    fi
fi

if [ -n "$ASSET_URL" ]; then
    echo "Downloading etherload archive from: $ASSET_URL"
    mkdir -p "$M65_DIR/tmp_tools"
    curl -L -o "$M65_DIR/tmp_tools/m65tools-mac.archive" "$ASSET_URL"
    
    echo "Extracting etherload..."
    # Detect file type based on URL and extract accordingly
    if echo "$ASSET_URL" | grep -qi "\.zip"; then
        unzip -o -q "$M65_DIR/tmp_tools/m65tools-mac.archive" -d "$M65_DIR/tmp_tools" 2>/dev/null
    elif echo "$ASSET_URL" | grep -qi "\.7z"; then
        SEVENZ_CMD=""
        if command -v 7zz &> /dev/null; then SEVENZ_CMD="7zz";
        elif command -v 7z &> /dev/null; then SEVENZ_CMD="7z";
        fi
        
        if [ -z "$SEVENZ_CMD" ]; then
            echo "Terminal needs '7zz' to extract this file. Installing sevenzip via Homebrew..."
            if ! command -v brew &> /dev/null; then
                echo "Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install sevenzip
            SEVENZ_CMD="7zz"
        fi
        $SEVENZ_CMD x "$M65_DIR/tmp_tools/m65tools-mac.archive" -o"$M65_DIR/tmp_tools" -y > /dev/null 2>&1
    else
        tar -xzf "$M65_DIR/tmp_tools/m65tools-mac.archive" -C "$M65_DIR/tmp_tools" 2>/dev/null || tar -xf "$M65_DIR/tmp_tools/m65tools-mac.archive" -C "$M65_DIR/tmp_tools" 2>/dev/null
    fi
    
    # Find etherload (case insensitive, allowing for possible suffixes like _mac)
    ETHERLOAD_BIN=$(find "$M65_DIR/tmp_tools" -type f -iname "*etherload*" | head -n 1)
    if [ -n "$ETHERLOAD_BIN" ]; then
        mv "$ETHERLOAD_BIN" "$M65_DIR/etherload"
    fi
    
    if [ -f "$M65_DIR/etherload" ]; then
        chmod +x "$M65_DIR/etherload"
        # Clear macOS Gatekeeper Quarantine and ad-hoc sign for Apple Silicon execution
        xattr -d com.apple.quarantine "$M65_DIR/etherload" 2>/dev/null
        codesign --force --deep -s - "$M65_DIR/etherload" 2>/dev/null
        echo "✅ etherload installed successfully!"
    else
        echo "❌ Failed to locate etherload inside the downloaded archive."
        echo "--- Debug Info: Contents of extracted archive ---"
        ls -laR "$M65_DIR/tmp_tools"
        echo "-------------------------------------------------"
    fi
    
    # Clean up temp folder
    rm -rf "$M65_DIR/tmp_tools"
else
    echo "❌ Could not auto-fetch mega65-tools. GitHub URL parsing failed."
fi

# 3. Fetch Standalone petcat from the MEGA65 Filehost
echo ""
echo "Fetching standalone petcat..."
PETCAT_URL="https://files.mega65.org/files/p/petcat-20230619_6Veruh.zip"
mkdir -p "$M65_DIR/tmp_petcat"
curl -L -o "$M65_DIR/tmp_petcat/petcat.zip" "$PETCAT_URL"

if [ -f "$M65_DIR/tmp_petcat/petcat.zip" ]; then
    echo "Extracting petcat..."
    unzip -o -q "$M65_DIR/tmp_petcat/petcat.zip" -d "$M65_DIR/tmp_petcat"
    
    # The zip contains mac, linux, and win versions. Find the mac one specifically.
    MAC_PETCAT=$(find "$M65_DIR/tmp_petcat" -type f -name "petcat" | grep -i "/mac" | head -n 1)
    
    # Fallback if the folder structure is flat or named differently
    if [ -z "$MAC_PETCAT" ]; then
        MAC_PETCAT=$(find "$M65_DIR/tmp_petcat" -type f -name "petcat" | grep -iv "/linux" | grep -iv "/win" | head -n 1)
    fi

    if [ -n "$MAC_PETCAT" ]; then
        mv "$MAC_PETCAT" "$M65_DIR/petcat"
    fi
    
    # Clean up temp folder
    rm -rf "$M65_DIR/tmp_petcat"
    
    if [ -f "$M65_DIR/petcat" ]; then
        chmod +x "$M65_DIR/petcat"
        # Clear macOS Gatekeeper Quarantine
        xattr -d com.apple.quarantine "$M65_DIR/petcat" 2>/dev/null
        echo "✅ petcat installed successfully!"
    else
        echo "❌ Failed to locate the Mac version of petcat inside the zip."
    fi
else
    echo "❌ Failed to download petcat. The direct link may have expired."
fi

# 4. Handle the xmega65 Application Bundle
echo ""
if [ -d "/Applications/xmega65.app" ]; then
    echo "Found xmega65 in /Applications. Creating symlink..."
    ln -sf "/Applications/xmega65.app/Contents/MacOS/xmega65" "$M65_DIR/xmega65"
elif [ -d "$HOME/Applications/xmega65.app" ]; then
    echo "Found xmega65 in User Applications. Creating symlink..."
    ln -sf "$HOME/Applications/xmega65.app/Contents/MacOS/xmega65" "$M65_DIR/xmega65"
else
    echo "Note: xmega65.app not found. Zed tasks using XEMU won't work until installed."
fi

# 5. Add the new tools directory to the user's ZSH PATH
ZSHRC="$HOME/.zshrc"
if ! grep -q "$M65_DIR" "$ZSHRC" 2>/dev/null; then
    echo "Adding $M65_DIR to your PATH in .zshrc..."
    echo "" >> "$ZSHRC"
    echo "# retroCombs MEGA65-ZED Tools" >> "$ZSHRC"
    echo "export PATH=\"\$PATH:$M65_DIR\"" >> "$ZSHRC"
else
    echo "Tools directory is already in your .zshrc PATH."
fi

echo ""
echo "=========================================================="
echo " VERIFYING INSTALLATION..."
echo "=========================================================="

# 1. Test petcat (using </dev/null to prevent terminal hang)
if [ -x "$M65_DIR/petcat" ] && "$M65_DIR/petcat" < /dev/null 2>&1 | grep -qi "petcat"; then
    echo "✅ petcat is installed and responding."
elif [ -x "$M65_DIR/petcat" ]; then
    echo "✅ petcat is installed and executable."
else
    echo "❌ petcat failed to run."
fi

# 2. Test etherload (using </dev/null to prevent terminal hang)
if [ -x "$M65_DIR/etherload" ] && "$M65_DIR/etherload" -h < /dev/null 2>&1 | grep -qi "etherload"; then
    echo "✅ etherload is installed and responding."
elif [ -x "$M65_DIR/etherload" ]; then
    echo "✅ etherload is installed and executable."
else
    echo "❌ etherload failed to run."
fi

# 3. Test xmega65 symlink
if [ -L "$M65_DIR/xmega65" ] && [ -x "$M65_DIR/xmega65" ]; then
    echo "✅ xmega65 symlink is valid and points to the app."
else
    echo "⚠️  xmega65 not found. (Emulator tasks in Zed will fail until installed)"
fi

echo ""
echo "=========================================================="
echo " SETUP COMPLETE!"
echo "=========================================================="
echo "IMPORTANT: Run 'source ~/.zshrc' or completely restart"
echo "your terminal/Zed for the PATH changes to take effect."
echo "=========================================================="