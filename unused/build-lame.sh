#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)
PREFIX="$BASE_DIR/PREFIX"

mkdir $PREFIX
echo "Prefix=$PREFIX"

do_svn_checkout() {
  repo_url="$1"
  to_dir="$2"
  desired_revision=""
  if [ ! -d $to_dir ]; then
    echo "svn checking out to $to_dir"
    if [[ -z "$desired_revision" ]]; then
      svn checkout $repo_url $to_dir.tmp  --non-interactive --trust-server-cert || exit 1
    else
      svn checkout -r $desired_revision $repo_url $to_dir.tmp || exit 1
    fi
    mv $to_dir.tmp $to_dir
  else
    cd $to_dir
    echo "not svn Updating $to_dir since usually svn repo's aren't updated frequently enough..."
    # XXX accomodate for desired revision here if I ever uncomment the next line...
    # svn up
    cd ..
  fi
}


build_mpg123() {
  do_svn_checkout svn://scm.orgis.org/mpg123/trunk mpg123_svn r5008 # avoid Think again failure
  cd mpg123_svn
    ./configure
    make -j8
    make install
  cd ..
}

build_lame() {
  do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
  cd lame_svn
    ./configure --enable-nasm --disable-decoder --prefix=${PREFIX}
    make -j8
    make install
  cd ..
}


# build_mpg123
# build_lame

