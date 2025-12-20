#!/bin/bash

cd "`dirname "$0"`"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)
setterm -linewrap off

pkgver="1.1.30"
destination_current="$(pwd)" # current dir: this_script.sh, lazarus, doublecmd-X.X.XX.(?:tar.gz|zip)
destination_tmp="/tmp"                                     # temporary dir
destination_compile="$destination_tmp/doublecmd-${pkgver}" # compilation dir
destination_final="$HOME/Desktop"                          # where result will be moved on finish

# Set processor architecture
# export CPU_TARGET=x86_64# export CPU_TARGET=aarch64
# export CPU_TARGET=arm
if [ -z "$CPU_TARGET" ]; then
  platform="$(fpc -iTP)"
  export CPU_TARGET=$platform
else
  platform="${CPU_TARGET}"
fi

lazbuild="$(which lazbuild)"
if [ -f "$lazbuild" ]; then
  echo "lazbuild exists, pass"
else
  # echo "lazbuild does not exist."
  lazbuild="${destination_current}/lazarus/lazbuild"
fi
lazbuild_dir=$(dirname "$lazbuild")
v="$(which fpc)"
echo -e "fpc::      ${v} (v$(fpc -iV))"
v="$("$lazbuild" -version)"
echo -e "lazbuild:: ${lazbuild} (v${v})"

copy_plugins()
{
  # first create WCX|WDX|WFX|WLX|DSX plugins directories
  mkdir -p "$DC_INSTALL_DIR"/plugins/wcx/{base64,cpio,deb,rpm,unrar,zip,sevenzip}
  mkdir -p "$DC_INSTALL_DIR"/plugins/wdx/{scripts,rpm_wdx,deb_wdx,audioinfo}
  mkdir -p "$DC_INSTALL_DIR"/plugins/wfx/{ftp,samba}
  mkdir -p "$DC_INSTALL_DIR"/plugins/wlx/{wlxmplayer,}
  mkdir -p "$DC_INSTALL_DIR"/plugins/dsx/{dsxlocate,}

  # copy plugins
  # WCX
  install -m 644 $compile_directory/plugins/wcx/base64/base64.wcx        $DC_INSTALL_DIR/plugins/wcx/base64/
  install -m 644 $compile_directory/plugins/wcx/cpio/cpio.wcx            $DC_INSTALL_DIR/plugins/wcx/cpio/
  install -m 644 $compile_directory/plugins/wcx/deb/deb.wcx              $DC_INSTALL_DIR/plugins/wcx/deb/
  install -m 644 $compile_directory/plugins/wcx/rpm/rpm.wcx              $DC_INSTALL_DIR/plugins/wcx/rpm/
  cp -r $compile_directory/plugins/wcx/unrar/language                    $DC_INSTALL_DIR/plugins/wcx/unrar
  install -m 644 $compile_directory/plugins/wcx/unrar/unrar.wcx          $DC_INSTALL_DIR/plugins/wcx/unrar/
  cp -r $compile_directory/plugins/wcx/zip/language                      $DC_INSTALL_DIR/plugins/wcx/zip
  install -m 644 $compile_directory/plugins/wcx/zip/zip.wcx              $DC_INSTALL_DIR/plugins/wcx/zip/
  cp -r $compile_directory/plugins/wcx/sevenzip/language                 $DC_INSTALL_DIR/plugins/wcx/sevenzip
  install -m 644 $compile_directory/plugins/wcx/sevenzip/sevenzip.wcx    $DC_INSTALL_DIR/plugins/wcx/sevenzip/
  # WDX
  install -m 644 $compile_directory/plugins/wdx/rpm_wdx/rpm_wdx.wdx      $DC_INSTALL_DIR/plugins/wdx/rpm_wdx/
  install -m 644 $compile_directory/plugins/wdx/deb_wdx/deb_wdx.wdx      $DC_INSTALL_DIR/plugins/wdx/deb_wdx/
  install -m 644 $compile_directory/plugins/wdx/scripts/*                $DC_INSTALL_DIR/plugins/wdx/scripts/
  install -m 644 $compile_directory/plugins/wdx/audioinfo/audioinfo.wdx  $DC_INSTALL_DIR/plugins/wdx/audioinfo/
  install -m 644 $compile_directory/plugins/wdx/audioinfo/audioinfo.lng  $DC_INSTALL_DIR/plugins/wdx/audioinfo/
  # WFX
  cp -r $compile_directory/plugins/wfx/ftp/language                      $DC_INSTALL_DIR/plugins/wfx/ftp
  install -m 644 $compile_directory/plugins/wfx/ftp/ftp.wfx              $DC_INSTALL_DIR/plugins/wfx/ftp/
  install -m 644 $compile_directory/plugins/wfx/ftp/src/ftp.ico          $DC_INSTALL_DIR/plugins/wfx/ftp/
  install -m 644 $compile_directory/plugins/wfx/samba/samba.wfx          $DC_INSTALL_DIR/plugins/wfx/samba/
  # WLX
  install -m 644 $compile_directory/plugins/wlx/WlxMplayer/wlxmplayer.wlx  $DC_INSTALL_DIR/plugins/wlx/wlxmplayer/
  # DSX
  install -m 644 $compile_directory/plugins/dsx/DSXLocate/dsxlocate.dsx    $DC_INSTALL_DIR/plugins/dsx/dsxlocate/
}

copy_finished_and_cleanup()
{
  # DC_INSTALL_DIR="/tmp/DC/"
  DC_INSTALL_DIR="$destination_final/doublecmd-${pkgver}_${framework}_${platform}/"
  echo "Copy from|to: $compile_directory | $DC_INSTALL_DIR"

  copy_plugins

  # Copy files
  cp -a $compile_directory/doublecmd                    $DC_INSTALL_DIR/
  cp -a $compile_directory/doublecmd.help               $DC_INSTALL_DIR/
  cp -a $compile_directory/doublecmd.zdli               $DC_INSTALL_DIR/
  cp -a $compile_directory/pinyin.tbl                   $DC_INSTALL_DIR/

  # Copy default settings
  cp -r $compile_directory/default                      $DC_INSTALL_DIR/

  # Make portable version
  mkdir $DC_INSTALL_DIR/settings
  touch $DC_INSTALL_DIR/settings/doublecmd.inf
  # Copy documentation
  mkdir -p $DC_INSTALL_DIR/doc
  cp -a $compile_directory/doc/*.txt $DC_INSTALL_DIR/doc/
  # Copy script for execute portable version
  cp -a $compile_directory/doublecmd.sh $DC_INSTALL_DIR/
  # Copy directories
  cp -r $compile_directory/language     $DC_INSTALL_DIR/
  cp -r $compile_directory/pixmaps      $DC_INSTALL_DIR/
  cp -r $compile_directory/highlighters $DC_INSTALL_DIR/
  # Copy scripts
  install -d         $DC_INSTALL_DIR/scripts
  cp -a $compile_directory/scripts/*.py $DC_INSTALL_DIR/scripts/
  # Copy libraries
  install -m 644 *.so*    $DC_INSTALL_DIR/
  # Copy DC icon
  cp -a $compile_directory/doublecmd.png     $DC_INSTALL_DIR/doublecmd.png


  # Clean up
  rm -r ${destination_compile} > /dev/null 2>&1; # just unpacked archive dir
  rm -r ${compile_directory}   > /dev/null 2>&1; # renamed tmp dir where compilation will be processed

  exit 0

  if [ -z $CK_PORTABLE ]; then
    # Share directory
    DC_USR_SHARE=$DC_INSTALL_PREFIX/usr/share/doublecmd
    # Copy libraries
    install -d                $DC_INSTALL_PREFIX/usr/lib$LIB_SUFFIX
    if [ "$(echo *.so*)" != "*.so*" ]; then
      install -m 644 *.so*    $DC_INSTALL_PREFIX/usr/lib$LIB_SUFFIX
    fi
    # Create directory for platform independed files
    install -d                $DC_USR_SHARE
    # Copy man files
    install -d -m 755                      $DC_INSTALL_PREFIX/usr/share/man/man1
    install -c -m 644 install/linux/*.1    $DC_INSTALL_PREFIX/usr/share/man/man1
    # Copy documentation
    install -d                $DC_USR_SHARE/doc
    install -m 644 doc/*.txt  $DC_USR_SHARE/doc
    ln -sf ../../share/doublecmd/doc $DC_INSTALL_DIR/doc
    # Copy scripts
    install -d         $DC_INSTALL_DIR/scripts
    cp -a scripts/*.py $DC_INSTALL_DIR/scripts/
    # Copy languages
    cp -r language $DC_USR_SHARE
    ln -sf ../../share/doublecmd/language $DC_INSTALL_DIR/language
    # Copy pixmaps
    cp -r pixmaps $DC_USR_SHARE
    ln -sf ../../share/doublecmd/pixmaps $DC_INSTALL_DIR/pixmaps
    touch -r $DC_USR_SHARE/pixmaps/dctheme $DC_USR_SHARE/pixmaps/dctheme/icon-theme.cache
    # Copy highlighters
    cp -r highlighters $DC_USR_SHARE
    ln -sf ../../share/doublecmd/highlighters $DC_INSTALL_DIR/highlighters
    # Create symlink and desktop files
    install -d $DC_INSTALL_PREFIX/usr/bin
    install -d $DC_INSTALL_PREFIX/usr/share/pixmaps
    install -d $DC_INSTALL_PREFIX/usr/share/applications
    install -d $DC_INSTALL_PREFIX/usr/share/icons/hicolor/scalable/apps
    ln -sf  ../lib$LIB_SUFFIX/doublecmd/doublecmd $DC_INSTALL_PREFIX/usr/bin/doublecmd
    install -m 644 doublecmd.png $DC_INSTALL_PREFIX/usr/share/pixmaps/doublecmd.png
    install -m 644 install/linux/doublecmd.desktop $DC_INSTALL_PREFIX/usr/share/applications/doublecmd.desktop
    ln -sf ../../../../doublecmd/pixmaps/mainicon/alt/dcfinal.svg \
           $DC_INSTALL_PREFIX/usr/share/icons/hicolor/scalable/apps/doublecmd.svg
    install -d $DC_INSTALL_PREFIX/usr/share/polkit-1/actions
    install -m 644 install/linux/org.doublecmd.root.policy $DC_INSTALL_PREFIX/usr/share/polkit-1/actions/
  else
    # Make portable version
    mkdir $DC_INSTALL_DIR/settings
    touch $DC_INSTALL_DIR/settings/doublecmd.inf
    # Copy documentation
    mkdir -p $DC_INSTALL_DIR/doc
    cp -a doc/*.txt $DC_INSTALL_DIR/doc/
    # Copy script for execute portable version
    cp -a doublecmd.sh $DC_INSTALL_DIR/
    # Copy directories
    cp -r language     $DC_INSTALL_DIR/
    cp -r pixmaps      $DC_INSTALL_DIR/
    cp -r highlighters $DC_INSTALL_DIR/
    # Copy scripts
    install -d         $DC_INSTALL_DIR/scripts
    cp -a scripts/*.py $DC_INSTALL_DIR/scripts/
    # Copy libraries
    install -m 644 *.so*    $DC_INSTALL_DIR/
    # Copy DC icon
    cp -a doublecmd.png     $DC_INSTALL_DIR/doublecmd.png
  fi
}

mycomp ()
{
  framework=$1 # GTK2, Qt5, Qt6
  compile_directory="${destination_compile}_${framework}_${platform}"

  # unpack archive
  if [ -e "${destination_current}/doublecmd-${pkgver}-src.tar.gz" ]; then
    tar xzf "${destination_current}/doublecmd-${pkgver}-src.tar.gz" -C "$destination_tmp" > /dev/null 2>&1;
  elif [ -e "${destination_current}/doublecmd-${pkgver}.zip" ]; then
    unzip "${destination_current}/doublecmd-${pkgver}.zip" -d "$destination_tmp" > /dev/null 2>&1;
  else
    echo "Any DC archive does not exist."
    exit 0
  fi

  # Edit install shell files:
  sed -e "s@=\$(which lazbuild)@=\"${lazbuild} --lazarusdir=${lazbuild_dir}\"@" -i "${destination_compile}/build.sh"
  sed -e 's/LIB_SUFFIX=.*/LIB_SUFFIX=/g' -i "${destination_compile}/install/linux/install.sh"
  sed -e '/doublecmd.zdli/d'             -i "${destination_compile}/install/linux/install.sh"

  mv ${destination_compile} "${compile_directory}"

  # Compile and move only if successful
  cd $compile_directory
  ${compile_directory}/build.sh build_release ${framework} \
    && copy_finished_and_cleanup
}

mycomp gtk2
mycomp qt5
# mycomp qt6
