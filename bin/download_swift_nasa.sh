#!/usr/bin/env bash
set -e

# This script downloads Swift observations from NASA's archive;
# The archive is available at 'ftp://legacy.gsfc.nasa.gov'.
# Specifically, given a Observation-ID and its corresponding Date,
# this script will download everything from XRT's 'products' directory
# and XRT's "clean" eventfiles (xrt/event/*_cl.evt).
#
# The script accepts three input parameters:
# * Swift Observation ID (eg, 00035393001)
# * Observation Date (eg, 2006_03)
# * Optionally, local archive path (where 'swift/data/obs/' goes)

# Base url of (NASA's) data archive, from where we gonna download the data
#
ARCHIVE_SERVER='ftp://legacy.gsfc.nasa.gov'
ARCHIVE_DIRECTORY='swift/data/obs'
ARCHIVE_URL="${ARCHIVE_SERVER}/${ARCHIVE_DIRECTORY}"


usage() {
  echo
  _file=$(basename $BASH_SOURCE)
  echo "Usage: $_file -d <date> -o <obsid> [-a <local-data-archive>]"
  echo
  echo "  -d : observation date; format is YYYY_MM"
  echo "  -o : swift observation id"
  echo "  -a : local swift data archive (the directory containing 'swift/data/obs')"
  echo
  exit 1
}


function download(){
  local YYYYMM="$1"
  local OBSID="$2"
  local ARCHIVE="$3"

  local LOCAL_DIR="${PWD}/log"
  [ -d $LOCAL_DIR ] || mkdir -p $LOCAL_DIR

  local FILE_LOG="${LOCAL_DIR}/${YYYYMM}_${OBSID}.log"
  local TARGET_DIR="${ARCHIVE_URL}/${YYYYMM}/${OBSID}"    # NOTICE the trailing '/'! This shit is important!
  local TARGET_DIR="${TARGET_DIR}/xrt"

  curl -s -l "$TARGET_DIR" > /dev/null || { 1>&2 echo "Could not reach '$TARGET_DIR'."; exit 1; }

  echo "    - things will be written to ${LOCAL_DIR}"
  echo "    - archive being recursively downloaded: ${TARGET_DIR}"

  echo "Transfer START time: `date`" >> "${FILE_LOG}"

  (
    cd $ARCHIVE
    WAIT=$(echo "scale=2 ; 2*$RANDOM/32768" | bc -l)
    sleep "$WAIT"s
    #>> "${FILE_LOG}" \
    #wget -r --no-verbose --no-parent -nH --cut-dirs=3 \
    #                      --wait=2 --random-wait \
    #                      "${TARGET_DIR}/event/*_cl.evt.gz" 2>&1
    #>> "${FILE_LOG}" \
    #wget -r --no-verbose --no-parent -nH --cut-dirs=3 \
    #                      --wait=2 --random-wait \
    #                      "${TARGET_DIR}/products" 2>&1
    declare -a EVTS=($(curl -l ${TARGET_DIR}/event/ | grep "_cl.evt.gz" ))
    declare -a PRDS=($(curl -l ${TARGET_DIR}/products/ ))
    echo ${EVTS[@]} | xargs -n1 -P3 -I{} wget -r --no-verbose \
                                                --no-parent -nH --cut-dirs=5 \
                                                --wait=2 --random-wait \
                                                ${TARGET_DIR}/event/{}
    echo ${PRDS[@]} | xargs -n1 -P3 -I{} wget -r --no-verbose \
                                                --no-parent -nH --cut-dirs=5 \
                                                --wait=2 --random-wait \
                                                ${TARGET_DIR}/products/{}
  )

  echo "Transfer STOP time: `date`" >> "${FILE_LOG}"
}

FORCE_DOWNLOAD=''
ARCHIVE="$PWD"

while getopts ":d:o:a:f" OPT; do
    case "${OPT}" in
        d)
            DATE=${OPTARG}
            ;;
        o)
            OBSID=${OPTARG}
            ;;
        a)
            ARCHIVE=${OPTARG}
            ;;
        f)
            FORCE_DOWNLOAD='1'
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "${DATE}" -a -n "${OBSID}" -a -n "${ARCHIVE}" ] || usage

LOCAL_ARCHIVE_DIR="${ARCHIVE}/${ARCHIVE_DIRECTORY}/${DATE}/${OBSID}/"
if [ -z "$FORCE_DOWNLOAD" ]; then
  if [ -d "$LOCAL_ARCHIVE_DIR" ]; then
    echo "========================================================="
    echo "Data '${DATE}/${OBSID}' already downloaded"
    echo "========================================================="
    exit 0
  fi
fi

# Guarantee destination directory exist
[ -d "$LOCAL_ARCHIVE_DIR" ] || mkdir -p $LOCAL_ARCHIVE_DIR 2> /dev/null

if [ ! -w ${LOCAL_ARCHIVE_DIR} ]; then
  1>&2 echo "You don't have enough permissions to write to '${LOCAL_ARCHIVE_DIR}'. Finishing."
  exit 1
fi

echo "========================================================="
TIME_INIT=$(date +%s)
echo "Downloading ${DATE}, observation $OBSID.."

download "${DATE}" "${OBSID}" "$LOCAL_ARCHIVE_DIR"

echo "..done."
TIME_DONE=$(date +%s)
TIME_ELAP=$((TIME_DONE-TIME_INIT))
echo "-------"
echo " - Time elapsed: $TIME_ELAP"s
echo "========================================================="
