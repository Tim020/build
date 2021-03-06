#!/bin/bash -h
#              (ignore SIGHUP)
#              
#       Staging (step 1 of 3) 
#              
#       Download and upload to s3
#       along with .staging files
set -e

if [[ ! ${WORKSPACE} ]] ; then WORKSPACE=`pwd` ; fi

TMP_DIR=${WORKSPACE}/release_tmp
PHONE_HOME=${WORKSPACE}/phone_home.txt
if [[ -e ${PHONE_HOME} ]] ; then rm -f ${PHONE_HOME} ; fi


usage()
    {
    echo ""
    echo "usage:  `basename $0`  RELEASE  VERSION  PRODUCT  EDITION  [ -D TMP_DIR ]"
    echo ""
    echo "           RELEASE        release number, like 3.0.0 or 2.5.2          "
    echo "           VERSION        prepared version, like 3.0.0 or 3.0.0-beta   "
    echo "           PRODUCT        android, ios, or sync_gateway (one only)     "
    echo "           EDITION        community or enterprise.                     "
    echo ""
    echo "          [-D TMP_DIR ]   temp dir to use, if not ${TMP_DIR}"
    echo ""
    echo "           -h             print this help message"
    echo ""
    exit 4
    }
if [[ $1 == "--help" ]] ; then usage ; fi


####    required, positional arguments

if [[ ! ${1} ]] ; then echo ; echo "RELEASE required (1.0.1, 1.0.0, ...)"          ; usage ; exit ; fi
release=${1}

if [[ ! ${2} ]] ; then echo ; echo "VERSION required (from prepare_release step)"  ; usage ; exit ; fi
version=${2}

if [[ ! ${3} ]] ; then echo ; echo "PRODUCT required (android, ios, sync_gateway)" ; usage ; exit ; fi
product=${3}

if [[ ! ${4} ]] ; then echo ; echo "EDITION required (enterprise, community)"      ; usage ; exit ; fi
edition=${4}

rel_dir=${release}/${version}
if [[ ${release} == ${version} ]] ; then rel_dir=${release} ; fi


####    optional, named arguments

while getopts "D:h" OPTION; do
  case "$OPTION" in
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


echo "Create tmp folder to hold all the packages"
rm      -rf ${TMP_DIR}
mkdir   -p  ${TMP_DIR}
chmod   777 ${TMP_DIR}
pushd       ${TMP_DIR}  2>&1 > /dev/null


s3_build_src="s3://packages.couchbase.com/builds/mobile/${product}/${release}/${version}"
GET_CMD="s3cmd get"
PUT_CMD="s3cmd put"

if  [[ ${product} == 'android' ]]
  then
    pkgs="couchbase-lite-android-${edition}_${version}.zip"
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${rel_dir}"
fi
 
if  [[ ${product} == 'ios' ]]
  then
    pkgs="couchbase-lite-ios-${edition}_${version}.zip couchbase-lite-ios-${edition}_${version}_Documentation.zip"
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-lite/${product}/${rel_dir}"
fi
 
if  [[ ${product} == 'sync_gateway' ]]
  then
    pkgs=""
    PREFIX="couchbase-sync-gateway"
    pkg_ends="x86_64.rpm  x86.rpm  x86_64.tar.gz  x86_64.deb  x86.deb  x86_64.exe  x86.exe"
    
    for end in ${pkg_ends[@]} ; do pkgs="$pkgs ${PREFIX}-${edition}_${version}_${end}" ; done
    
    s3_relbucket="s3://packages.couchbase.com/releases/couchbase-sync-gateway/${rel_dir}"
fi

####################   S T A R T  H E R E


for this_pkg in ${pkgs[@]}
  do
    echo "Staging:  ${s3_relbucket}/${this_pkg}"
    echo "download  ${s3_build_src}/${this_pkg}"
    ${GET_CMD}      ${s3_build_src}/${this_pkg}
    
    if [[ ! -e ${this_pkg} ]] ; then echo "FAILED to download ${s3_build_src}/${this_pkg}" ; exit 404 ; fi
    
    echo "create staging file for ${this_pkg}"
    touch "${this_pkg}.staging"
    
    echo "calculate md5sum for   ${this_pkg}"
    md5sum ${this_pkg} > ${this_pkg}.md5
    
    ${PUT_CMD}  ${this_pkg}.staging  ${s3_relbucket}/${this_pkg}.staging
    ${PUT_CMD}  ${this_pkg}.md5      ${s3_relbucket}/${this_pkg}.md5
    ${PUT_CMD}  ${this_pkg}          ${s3_relbucket}/${this_pkg}
    rm          ${this_pkg}
    echo        ${this_pkg}  >>  ${PHONE_HOME}
done
 
echo "Granting anonymous read access..."
s3cmd setacl --acl-public --recursive "${s3_relbucket}/"

s3cmd ls "${s3_relbucket}/"
popd                    2>&1 > /dev/null
