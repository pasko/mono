#!/bin/bash
# Copyright (c) 2009 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-runtime-mono.sh
#
# usage:  nacl-runtime-mono.sh
#
# this script builds mono runtime for Native Client 
#

readonly MONO_TRUNK_NACL=$(pwd)

source common.sh
source nacl-common.sh

readonly PACKAGE_NAME=runtime${TARGET_BIT_PREFIX}-build
readonly INSTALL_PATH=${NACL_SDK_USR}


CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  set +e
  if [ -f ${PACKAGE_NAME}/Makefile ]
  then
    cd ${PACKAGE_NAME}
  fi
  make distclean
  cd ${MONO_TRUNK_NACL}
  set -e
  if [ $NACL_NEWLIB = "1" ]; then
    NACL_NEWLIB_DEFINE=-DNACL_NEWLIB
    CONFIG_OPTS="--host=nacl${TARGET_BIT_PREFIX} --disable-shared --cache-file=../config-nacl-runtime${TARGET_BIT_PREFIX}.cache.temp"
  else
    NACL_NEWLIB_DEFINE=
    CONFIG_OPTS="--enable-shared --disable-parallel-mark"
    if [ $TARGET_BITSIZE == '32' ]; then
      CONFIG_OPTS="--host=i386-pc-linux --build=i386-pc-linux --target=i386-pc-linux ${CONFIG_OPTS}"
    else
      CONFIG_OPTS="--host=x86_64-pc-linux --build=x86_64-pc-linux --target=x86_64-pc-linux ${CONFIG_OPTS}"
    fi
    # UGLY hack to allow dynamic linking
    sed -i -e s/elf_i386/elf_nacl/ -e s/elf_x86_64/elf64_nacl/ ../configure
    sed -i -e s/elf_i386/elf_nacl/ -e s/elf_x86_64/elf64_nacl/ ../libgc/configure
    sed -i -e s/elf_i386/elf_nacl/ -e s/elf_x86_64/elf64_nacl/ ../eglib/configure
  fi
  cp config-nacl-runtime${TARGET_BIT_PREFIX}.cache config-nacl-runtime${TARGET_BIT_PREFIX}.cache.temp
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  cd ${PACKAGE_NAME}
  CC=${NACLCC} CXX=${NACLCXX} AR=${NACLAR} RANLIB=${NACLRANLIB} PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig LD="${NACLLD}" \
  PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB} PATH=${NACL_BIN_PATH}:${PATH} LIBS="-lnacl_dyncode -lc -lg -lnosys -lnacl" \
  CFLAGS="-g -O0 -D_POSIX_PATH_MAX=256 -DPATH_MAX=256 ${NACL_NEWLIB_DEFINE}" ../../configure \
    ${CONFIG_OPTS} \
    --exec-prefix=${INSTALL_PATH} \
    --libdir=${INSTALL_PATH}/lib \
    --prefix=${INSTALL_PATH} \
    --oldincludedir=${INSTALL_PATH}/include \
    --disable-mcs-build \
    --with-glib=embedded \
    --with-tls=pthread \
    --enable-threads=posix \
    --without-sigaltstack \
    --without-mmap \
    --with-gc=included \
    --enable-nacl-gc \
    --with-sgen=no \
    --enable-nls=no \
    --enable-nacl-codegen
  echo "// --- Native Client runtime below" >> config.h
  echo "#define pthread_cleanup_push(x, y)" >> config.h
  echo "#define pthread_cleanup_pop(x)" >> config.h
  echo "#undef HAVE_EPOLL" >> config.h
  echo "#undef HAVE_WORKING_SIGALTSTACK" >> config.h
  echo "extern long int timezone;" >> config.h
  echo "extern int daylight;" >> config.h
  echo "#define sem_trywait(x) sem_wait(x)" >> config.h
  echo "#define sem_timedwait(x,y) sem_wait(x)" >> config.h
if [ $NACL_NEWLIB = "1" ]; then
  echo "#define getdtablesize() (32768)" >> config.h
fi 
  echo "// --- Native Client runtime below" >> eglib/src/eglib-config.h
  echo "#undef G_BREAKPOINT" >> eglib/src/eglib-config.h
  echo "#define G_BREAKPOINT() G_STMT_START { __asm__ (\"hlt\"); } G_STMT_END" >> eglib/src/eglib-config.h
  rm ../config-nacl-runtime${TARGET_BIT_PREFIX}.cache.temp
}

CustomInstallStep() {
  make install
  CopyNormalMonoLibs
}

CustomPackageInstall() {
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
