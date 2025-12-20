#! /bin/sh

mkdir -p $HOME/bin/FPC/{SRC,fpc-3.2.2}
# Download archives:
# https://sourceforge.net/projects/freepascal/files/Linux/3.2.2/
# https://sourceforge.net/projects/freepascal/files/Linux/3.2.2/fpc-3.2.2.aarch64-linux.tar/download
# https://sourceforge.net/projects/freepascal/files/Linux/3.2.2/fpc-3.2.2.x86_64-linux.tar/download
# https://sourceforge.net/projects/freepascal/files/Source/3.2.2/fpc-3.2.2.source.tar.gz

# Unpack archives
tar xzf fpc-3.2.2.source.tar.gz   -C "$HOME/bin/FPC/SRC/"
tar xf "fpc-3.2.2.$(uname -m)-linux.tar" -C "$HOME/bin/FPC/"

# To execute install must be in working dir:
cd "$HOME/bin/FPC/fpc-3.2.2.$(uname -m)-linux" # (fpc-3.2.2.x86_64-linux)

# This automatically replaces path in the script to prepared destination
INSTALL_LOC="$HOME/bin/FPC/fpc-3.2.2.$(uname -m)-linux/install.sh"

# In original file is: echo "when asked where to install, enter $HOME/bin/FPC/fpc-3.2.2"
# This is replacement for the path where fpc will be installed (~/bin/FPC/fpc-3.2.2)
NEW_PREFIX='PREFIX="$HOME\/bin\/FPC\/fpc-3.2.2"'
SUBSTITUTE="s/ask .Install prefix (.usr or .usr.local) . PREFIX/${NEW_PREFIX}/g"
sed -e "$SUBSTITUTE" -i "$INSTALL_LOC"

# Accept all defaults for installation
./install.sh
rm -r "$HOME/bin/FPC/fpc-3.2.2.$(uname -m)-linux" # remove instalation files

# Use ~/.profile instead of ~/.bashrc so that the path is available also in Lazarus IDE.
echo "PATH=\"\$HOME/bin/FPC/fpc-3.2.2/bin\":\"\$PATH\"" >> ~/.bashrc # for bash
source ~/.bashrc

# Test
cd;fpc -iV;echo "fpc command should work in newly opened terminals if version was printed"
