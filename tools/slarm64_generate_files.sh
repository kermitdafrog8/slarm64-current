#!/bin/bash


if [[ -z "$1" || ! -d "$1" ]]; then
    echo "Required argument '$1' must be a directory!"
    exit 1
fi

DIR="$1"
DISTR="slarm64"
FILELIST=${FILELIST:-FILE_LIST}
PACKAGES="PACKAGES.TXT"
CHECKSUMS="CHECKSUMS.md5"
EXCLUDES=".git"


PRUNES=""
for substr in $EXCLUDES ; do
    PRUNES="${PRUNES} -name ${substr} -prune -o -true"
done




### gen_data
get_data() {
    local _DATE=$(LANG=C date -u)
    eval "$1=\${_DATE}"
}


### gen_filelist
gen_filelist() {
  # Argument #1 : full path to a directory
  # Argument #2 : output filename

  local DIR=$1
  local LISTFILE=$2

  get_data UPDATE_DATE

  pushd $DIR 2>&1>/dev/null

  # shrink file
  > ${LISTFILE}

  cat <<EOT > ${LISTFILE}
$UPDATE_DATE

Here is the file list for this directory.  If you are using a 
mirror site and find missing or extra files in the disk 
subdirectories, please have the archive administrator refresh
the mirror.

EOT
    find -L . $PRUNES -print | sort | xargs ls -ld --time-style=long-iso >> ${LISTFILE}
  popd 2>&1>/dev/null
}


### gen_file_packages
gen_file_packages() {
  # Argument #1 : full path to a directory

  local DIR=$1

  pushd $DIR 2>&1>/dev/null

  local _DIR=$(basename $DIR)

  # shrink file
  > ${PACKAGES}

  get_data UPDATE_DATE

  PKGS=$( find -L . $PRUNES -type f -name '*.txz' -print | sort -t'/' -k3)

  for PKG in $PKGS; do
    LOCATION="./${_DIR}"$(echo $PKG | rev | cut -f2- -d '/' | rev | sed "s/^.*\(\/.*\)$/\1/")
    NAME=$(basename $PKG)
    SIZE=$(du -s $PKG | cut -f 1)
    USIZE=$(xz --robot --list $PKG | awk '/^totals/{printf("%i"), $5/1024}')

    cat <<EOT >> ${PACKAGES}

PACKAGE NAME:  $NAME
PACKAGE LOCATION:  $LOCATION
PACKAGE SIZE (compressed):  $SIZE K
PACKAGE SIZE (uncompressed):  $USIZE K
PACKAGE DESCRIPTION:
EOT
    cat $PKG | tar xJOf - install/slack-desc | sed -n '/^#/d;/:/p' >> ${PACKAGES}
  done

  SIZE=$(grep '(compressed):' ${PACKAGES} | awk '{SUM += $4} END {printf("%i"), SUM/1024}')
  USIZE=$(grep '(uncompressed):' ${PACKAGES} | awk '{SUM += $4} END {printf("%i"), SUM/1024}')

  read -r -d '' HEAD << EOT
$PACKAGES;  $UPDATE_DATE

This file provides details on the $DISTR packages found
in the ./${_DIR}/ directory.

Total size of all packages (compressed):  $SIZE MB
Total size of all packages (uncompressed):  $USIZE MB
EOT

  awk -i inplace -v p="\n$HEAD\n" 'BEGINFILE{print p}{print}' ${PACKAGES}

  popd 2>&1>/dev/null
}


### gen_file_checksums
gen_file_checksums() {
  # Argument #1 : full path to a directory

  local DIR=$1

  pushd $DIR 2>&1>/dev/null

  # shrink file
  > $CHECKSUMS

  cat <<EOT >> ${CHECKSUMS}
These are the MD5 message digests for the files in this directory.
If you want to test your files, use 'md5sum' and compare the values to
the ones listed here.

To test all these files, use this command:

tail +13 CHECKSUMS.md5 | md5sum -c --quiet - | less

'md5sum' can be found in the GNU coreutils package on ftp.gnu.org in
/pub/gnu, or at any GNU mirror site.

MD5 message digest                Filename
EOT

  find -L . $PRUNES -type f -print | sort | xargs md5sum >> ${CHECKSUMS}

  popd 2>&1>/dev/null
}



#gen_file_packages $DIR
#gen_filelist $DIR $FILELIST
#gen_file_checksums $DIR

for d in $DIR/*;do
  if [[ -d ${d} ]]; then
    echo "generate for $d"
    if [[ $(echo ${d} | grep $DISTR$) ]]; then
        gen_file_packages ${d}
        cp ${d}/$PACKAGES $DIR/$PACKAGES
        ln -sf $DIR/$PACKAGES -r ${d}/$PACKAGES
    fi
    gen_filelist ${d} $FILELIST
    gen_file_checksums ${d}
  fi
done

# base distro directory
gen_filelist $DIR "FILELIST.TXT"
gen_file_checksums $DIR
