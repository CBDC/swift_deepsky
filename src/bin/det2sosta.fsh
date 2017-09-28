#!/usr/bin/env bash
set -u

det2sosta() {
  # FILE is the .det
  local FILE="$1"
  local BACKFILE="$2"
  local EMIN="$3"
  local EMAX="$4"
  local EXPOFILE="$5"
  local LOGFILE="$6"
  # Independent of the band we'are processing,
  # drop the full-band detection countrates to this file:
  local CTSFILE="$7"
  local NAME="$8"

  file=$(grep "^! Inpu" $FILE | awk '{print $NF}')
  expo=$(grep "^! Expo" $FILE | awk '{print $NF}')
  back=$(grep "^! Back" $BACKFILE | awk '{print $NF}')

  # echo "log test_$EMIN-$EMAX.txt"
  echo "log $LOGFILE"
  echo "read/size=1024/ecol=PI/emin=${EMIN}/emax=${EMAX} $file"
  echo "read/size=1024/expo $EXPOFILE"
  echo "cpd ${NAME}_sum_band${EMIN}-${EMAX}daeV.gif/gif"
  echo 'disp'

  # Full-band countrates sub-product (CTSFILE)
  echo "#RA DEC photon_flux[cts/s] photon_flux_error[cts/s]" > $CTSFILE

  OLDIFS="$IFS"
  IFS=$'\n' DETECTS=($(grep -v "^!" $FILE))
  IFS="$OLDIFS"
  NUMDETECTS=${#DETECTS[@]}
  for ((i=0; i<$NUMDETECTS; i++)); do

    read -a FIELDS <<< ${DETECTS[$i]}

    ctrate=${FIELDS[1]%%+*}
    _err=${FIELDS[1]##*+}
    errate=${_err#*-}

    ra="${FIELDS[5]}:${FIELDS[6]}:${FIELDS[7]}"
    dec="${FIELDS[8]}:${FIELDS[9]}:${FIELDS[10]}"

    # Full-band countrates sub-product (CTSFILE)
    echo "$ra $dec $ctrate $errate" >> $CTSFILE

    counts=$(echo "$ctrate $expo" | awk '{print $1 * $2}')
    counts=${counts%%.*}

    xpix=${FIELDS[2]}
    ypix=${FIELDS[3]}

    eef_size=0.9
    if [ $counts -lt 100 ]; then
      eef_size=0.6
    elif [ $counts -lt 500 ]; then
      eef_size=0.7
    elif [ $counts -lt 2000 ]; then
      eef_size=0.8
    fi

    echo "sosta/xpix=${xpix}/ypix=${ypix}/back=${back}/eef_s=${eef_size}"

    # for ((j=0; j<${#FIELDS[@]}; j++)); do
    #   echo ${FIELDS[$j]}
    # done
  done

  echo 'exit'
}