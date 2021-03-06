#!/bin/bash
clear
while true; do
	read -p "When you flash the ROM be aware that lock screen and fingerprint can be removed easily, to prevent this encrypt your phone. Check community.e.foundation if your model supports encryption. I understand this message and want to coninue:(y/n)" yn
    case $yn in
          [Yy]* ) break;; 
	  [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Install build dependencies
############################
apt -qq update
apt -qqy upgrade
apt install -y imagemagick libwxgtk3.0-dev openjdk-8-jdk
apt install -y openjdk-7-jdk
apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick libncurses5 lib32ncurses5-dev lib32readline-dev lib32z1-dev libtinfo5 liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev python python3 software-properties-common git

#install google repo
####################
mkdir ~/bin 2>/dev/null
PATH="$HOME/bin:$PATH"
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

# Environment variables
#######################
export TMP_DIR=/srv/tmp

export SRC_DIR=/srv/src
export CCACHE_DIR=/srv/ccache
export ZIP_DIR=/srv/zips
export LMANIFEST_DIR=/srv/local_manifests
export DELTA_DIR=/srv/delta
export KEYS_DIR=/srv/keys
export LOGS_DIR=/srv/logs
export USERSCRIPTS_DIR=/srv/userscripts

export DEBIAN_FRONTEND=noninteractive
export USER=root

# Configurable environment variables
####################################
# By default we want to use CCACHE, you can disable this
# WARNING: disabling this may slow down a lot your builds!
export USE_CCACHE=1

# ccache maximum size. It should be a number followed by an optional suffix: k,
# M, G, T (decimal), Ki, Mi, Gi or Ti (binary). The default suffix is G. Use 0
# for no limit.
export CCACHE_SIZE=50G

# Clean artifacts output after each build
export CLEAN_AFTER_BUILD=true

# If you want to preserve old ZIPs set this to 'false'
export CLEAN_OUTDIR=false

# Include proprietary files, downloaded automatically from github.com/TheMuppets/
# Only some branches are supported
export INCLUDE_PROPRIETARY=false

# Environment for the LineageOS branches name
# See https://github.com/LineageOS/android_vendor_cm/branches for possible options
#
export BRANCH_NAME='v0.12.3-pie'

# Environment for the device
# eg. DEVICE=hammerhead
export DEVICE_LIST='FP3'

# Release type string
export RELEASE_TYPE='UNOFFICIAL'
#export LLVM_ENABLE_THREADS=1

# Repo use for build
export REPO='https://gitlab.e.foundation/e/os/releases.git'

# Repo use for build
export MIRROR=''

# OTA URL that will be used inside CMUpdater
# Use this in combination with LineageOTA to make sure your device can auto-update itself from this buildbot
export OTA_URL='https://your-ota-server.com/api'

# User identity
export USER_NAME='anonymous'
export USER_MAIL='anonymous@xyz.com'

# Change this cron rule to what fits best for you
# Use 'now' to start the build immediately
# For example, '0 10 * * *' means 'Every day at 10:00 UTC'
export CRONTAB_TIME='now'

# Provide a default JACK configuration in order to avoid out-of-memory issues
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G"

# Custom packages to be installed
export CUSTOM_PACKAGES='PdfViewer GmsCore GsfProxy FakeStore com.google.android.maps.jar Mail BlissLauncher BlissIconPack MozillaNlpBackend OpenWeatherMapWeatherProvider AccountManager MagicEarth Camera eDrive Weather Notes Tasks NominatimNlpBackend DroidGuard OpenKeychain Message Browser BrowserWebView Apps LibreOfficeViewer'

# Sign the builds with the keys in $KEYS_DIR
export SIGN_BUILDS=false

# When SIGN_BUILDS = true but no keys have been provided, generate a new set with this subject
export KEYS_SUBJECT='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'

# Move the resulting zips to $ZIP_DIR/$codename instead of $ZIP_DIR/
export ZIP_SUBDIR=true

# Write the verbose logs to $LOGS_DIR/$codename instead of $LOGS_DIR/
export LOGS_SUBDIR=true

# Generate delta files
export BUILD_DELTA=false

# Backup the .img in addition to zips
export BACKUP_IMG=false

# Delete old zips in $ZIP_DIR, keep only the N latest one (0 to disable)
export DELETE_OLD_ZIPS=0

# Delete old deltas in $DELTA_DIR, keep only the N latest one (0 to disable)
export DELETE_OLD_DELTAS=0

# Delete old logs in $LOGS_DIR, keep only the N latest one (0 to disable)
export DELETE_OLD_LOGS=0

# Create a JSON file that indexes the build zips at the end of the build process
# (for the updates in OpenDelta). The file will be created in $ZIP_DIR with the
# specified name; leave empty to skip it.
# Requires ZIP_SUBDIR.
export OPENDELTA_BUILDS_JSON=''

# You can optionally specify a USERSCRIPTS_DIR volume containing these scripts:
#  * begin.sh, run at the very beginning
#  * before.sh, run after the syncing and patching, before starting the builds
#  * pre-build.sh, run before the build of every device
#  * post-build.sh, run after the build of every device
#  * end.sh, run at the very end
# Each script will be run in $SRC_DIR and must be owned and writeable only by
# root

# Create missing directories
############################
mkdir -p $TMP_DIR

mkdir -p $SRC_DIR
mkdir -p $CCACHE_DIR
mkdir -p $ZIP_DIR
mkdir -p $LMANIFEST_DIR
mkdir -p $DELTA_DIR
mkdir -p $KEYS_DIR
mkdir -p $LOGS_DIR
mkdir -p $USERSCRIPTS_DIR

# Copy build files to  /root/
############################
rm -rf $TMP_DIR/buildscripts
git clone https://gitlab.e.foundation/e/os/docker-lineage-cicd.git $TMP_DIR/buildscripts

rm -rf /root/*
cp -rf $TMP_DIR/buildscripts/src/* /root/
cp -rf $TMP_DIR/buildscripts/build-community.sh /root/build.sh

# Install build dependencies
############################
cp $TMP_DIR/buildscripts/apt_preferences /etc/apt/preferences

# Download and build delta tools
################################
cd /root/ && \
        mkdir delta && \
        echo "cloning"
        git clone --depth=1 https://gitlab.e.foundation/e/os/android_packages_apps_OpenDelta.git OpenDelta && \
        gcc -o delta/zipadjust OpenDelta/jni/zipadjust.c OpenDelta/jni/zipadjust_run.c -lz && \
        cp OpenDelta/server/minsignapk.jar OpenDelta/server/opendelta.sh delta/ && \
        chmod +x delta/opendelta.sh && \
        rm -rf OpenDelta/ && \
        sed -i -e "s|^\s*HOME=.*|HOME=/root|; \
                   s|^\s*BIN_XDELTA=.*|BIN_XDELTA=xdelta3|; \
                   s|^\s*FILE_MATCH=.*|FILE_MATCH=lineage-\*.zip|; \
                   s|^\s*PATH_CURRENT=.*|PATH_CURRENT=$SRC_DIR/out/target/product/$DEVICE|; \
                   s|^\s*PATH_LAST=.*|PATH_LAST=$SRC_DIR/delta_last/$DEVICE|; \
                   s|^\s*KEY_X509=.*|KEY_X509=$KEYS_DIR/releasekey.x509.pem|; \
                   s|^\s*KEY_PK8=.*|KEY_PK8=$KEYS_DIR/releasekey.pk8|; \
                   s|publish|$DELTA_DIR|g" /root/delta/opendelta.sh

# Set the work directory
########################
cd $SRC_DIR

# Allow redirection of stdout to docker logs
############################################
ln -sf /proc/1/fd/1 /var/log/docker.log

# Set the entry point to init.sh
################################
/root/init.sh

#end script

