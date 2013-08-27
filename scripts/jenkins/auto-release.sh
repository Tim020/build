#!/bin/bash

usage(){
    echo "Usage:"
    echo "./auto_release {VERSION}. {VERSION} is something like 2.0.2"
    echo "By default the script will handle packages for all names, platform and package types"
    echo "If you want to specify platform, name or types, usage is:"
    echo "NAME={NAME} PLATFORM={PLATFORM} TYPE={TYPE} OS_TYPE={0|1} ./auto_release {VERSION}"
}

if [ $# -eq 0 ]; then
    echo "Build number is not provided"
    exit
fi

if [ $1 = "--help" ] || [ $1 = "-h" ]; then
    usage
    exit
fi

if [ -z "$TYPE" ]; then
    echo "Stage packages for all types"
    types=("rpm" "deb" "setup.exe" "zip")
else
    echo "Stage packages for $TYPE"
    types=$TYPE
fi

if [ -z "$PLATFORM" ]; then
    echo "Stage packages for both 32 and 64 bits"
    platforms=(32 64)
else
    echo "Stage packages for $PLATFORM"
    platforms=$PLATFORM
fi

if [ -z "$NAME" ]; then
    echo "Stage packages for both enterprise and community editions"
    names=("enterprise" "community")
else
    echo "Stage packages for $NAME"
    names=$NAME
fi

if [ -z "$OS_TYPE" ]; then
    echo "Stage for newer (0) and older (1) packages"
    os_types=(0 1)
else
    os_types=$OS_TYPE
fi

for package_type in ${types[@]}; do
    for platform in ${platforms[@]}; do
        for name in ${names[@]}; do
            for os_type in ${os_types[@]}; do
                if [ $platform -eq 32 ] && [ $package_type == "zip" ]; then
                    echo "MAC package doesn't support 32 bit platform"
                else
                    if [ $platform -eq 32 ]; then
                        if [ $os_type -eq 0 ]; then
                            staging="couchbase-server-${name}_x86_${1}.${package_type}.staging"
                        else
                            if [ $package_type == "rpm" -o $package_type == "deb" ]; then
                                staging="couchbase-server-${name}_x86_${1}_openssl098.${package_type}.staging"
                            fi
                        fi
                    else
                        if [ $os_type -eq 0 ]; then
                            staging="couchbase-server-${name}_x86_${platform}_${1}.${package_type}.staging"
                        else
                            if [ $package_type == "rpm" -o $package_type == "deb" ]; then
                                staging="couchbase-server-${name}_x86_${platform}_${1}_openssl098e.${package_type}.staging"
                            fi
                        fi
                    fi

                    echo "Remove staging file for $staging and ready for release"
                    s3cmd del "s3://packages.couchbase.com/releases/${1}/${staging}"
                    if [ $name == "community" ];
                    then
                        base_name=couchbase-server_src-${1}.tar.gz
                        s3cmd del "s3://packages.couchbase.com/releases/${1}/${base_name}.staging"
                    fi
                fi
            done
        done
    done
done
