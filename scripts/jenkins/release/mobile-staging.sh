#!/bin/bash -h
#              Download and upload to s3
#              along with .staging files

TMP_DIR=~/release_tmp

usage()
    {
    echo ""
    echo "usage:  `basename $0`  VERSION  [ -m MODEL -e EDITION ]"
    echo ""
    echo "           VERSION          prepared version, like 3.0.0 or 3.0.0-beta   "
    echo ""
    echo "          [ -m MODEL ]      android, ios, or sync_gateway (one only)     "
    echo "          [ -e EDITION  ]   community or enterprise.                     "
    echo ""
    echo "          [ -D TMP_DIR  ]   temp dir to use, if not ${TMP_DIR}"
    echo ""
    echo "          [ -h          ]   print this help message"
    echo ""
    exit 4
    }
if [[ $1 == "--help" ]] ; then usage ; fi

####    required, positional arguments

if [[ ! ${1} ]] ; then echo ; echo "VERSION required" ; usage ; exit ; fi
version=${1}
shift

vrs_rex='([0-9]\.[0-9])-([0-9]{1,})'

if [[ $version =~ $vrs_rex ]]
  then
    for N in 1 2 ; do
        if [[ $N -eq 1 ]] ; then rel_num=${BASH_REMATCH[$N]} ; fi
        if [[ $N -eq 2 ]] ; then bld_num=${BASH_REMATCH[$N]} ; fi
    done
else
    echo ""
    echo "bad version number: ${version}"
    usage
    exit
fi

####    optional, named arguments

while getopts "m:e:h" OPTION; do
  case "$OPTION" in
      m)
        MODEL="$OPTARG"
        ;;
      e)
        EDITION="$OPTARG"
        ;;
      D)
        TMP_DIR="$OPTARG"
        ;;
      h)
        usage
        exit 0
        ;;
      *)
        usage
        exit 9
        ;;
  esac
done

if [ -z "$MODEL" ]; then
    echo "Stage packages for $MODEL"
    platforms=$MODEL
else
    echo "Must choose one of: android, ios, sync_gateway"
    exit 99
fi

rm ~/home_phone.txt

echo "Create tmp folder to hold all the packages"
rm      -rf ${TMP_DIR}
mkdir   -p  ${TMP_DIR}
chmod   777 ${TMP_DIR}
pushd       ${TMP_DIR}  2>&1 > /dev/null


s3_build_src="s3://packages.couchbase.com/builds/mobile/$MODEL/${rel_num}/${version}"
s3_relbucket="s3://packages.couchbase.com/releases/$MODEL/${version}/"
#                                                    must end with "/"
GET_CMD="s3cmd get"
PUT_CMD="s3cmd put"

if  [[ $MODEL == 'android' ]]
    then
    if [[ $EDITION == 'enterprise' ]]  ; then  pkgs="couchbase-lite-${version}.zip"           ; fi
    if [[ $EDITION == 'community'  ]]  ; then  pkgs="couchbase-lite-${version}-community.zip" ; fi
fi
 
if  [[ $MODEL == 'ios' ]]
    then
    if [[ $EDITION == 'enterprise' ]]  ; then  pkgs="couchbase-lite-ios-enterprise_${version}.zip couchbase-lite-ios-enterprise_${version}_Documentation.zip" ; fi
    if [[ $EDITION == 'community'  ]]  ; then  pkgs="couchbase-lite-ios-community_${version}.zip  couchbase-lite-ios-community_${version}_Documentation.zip"  ; fi
fi
 
if  [[ $MODEL == 'sync_gateway' ]]
    then
    EE_pkgs="x86_64.rpm            i386.rpm             macosx-x86_64.tar.gz            amd64.deb            i386.deb            amd64.exe           x86.exe"
    CE_pkgs="x86_64-community.rpm  i386-community.rpm   macosx-x86_64-community.tar.gz  amd64-community.deb  i386-community.deb  amd64-community.exe x86-community.exe"
    PREFIX="couchbase-sync-gateway"
    
    if [[ $EDITION == 'enterprise' ]] ; then  pkg_ends=$EE_pkgs ; fi
    if [[ $EDITION == 'community' ]]  ; then  pkg_ends=$CE_pkgs ; fi
    pkgs=""
    for src in ${pkg_ends[@]}
      do
        pkgs="$pkgs ${PREFIX}_${version}_${src}"
    done
fi


for this_pkg in ${pkgs[@]}
  do
    ${GET_CMD}  ${s3_build_src}/${this_pkg}
    
    echo "Staging for ${this_pkg}"
    touch "${this_pkg}.staging"
    
    echo "Calculate md5sum for ${this_pkg}"
    md5sum ${this_pkg} > ${this_pkg}.md5
    
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}.staging
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}.md5
    echo --------- ${PUT_CMD}  ${s3_relbucket}/${this_pkg}
    echo $package >> ~/home_phone.txt
    echo --------- rm ${this_pkg}
done
 
echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive "${s3_relbucket}"

s3cmd ls ${s3_relbucket}
popd                    2>&1 > /dev/null
