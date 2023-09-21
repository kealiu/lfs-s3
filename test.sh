#!/bin/bash -x

ENVRC="$1"

# This file takes as an argument the .envrc file where variables are defined.
if [ -z "$1" ]
then
  echo "Please provide the path to the .envrc file, or the default ./.envrc will be used "
  ENVRC=${PWD}/.envrc
fi

# Use a variant of the program to see input and output to the program.
go build &&\
echo -e "#!/usr/bin/env sh\n\ntee -a ../input.log | ../../lfs-s3 --debug 2> ../error.log | tee -a ../output.log >&1\n" > lfs-s3.sh &&\
chmod +x lfs-s3.sh &&\
rm -rf test &&\
mkdir test &&\
cd test && (
  mkdir fake-remote-repo && cd fake-remote-repo
  git init --bare
  cd ..
  git clone --progress fake-remote-repo local-repo &&\
    cd local-repo && (
      echo "# This is a lfs-s3 test." > README.md
      git add README.md
      git commit -m "Add pre-lfs commit."
      git push origin master
      git lfs install --local
      git lfs track "*.bin"
      git add .gitattributes
      git commit -m "Adding .gitattributes"
      git config --add lfs.customtransfer.lfs-s3.path ../../lfs-s3.sh
      git config --add lfs.standalonetransferagent lfs-s3
      git config --add lfs.concurrenttransfers 2
      dd if=/dev/random of=blob1.bin bs=1024 count=1024
      dd if=/dev/random of=blob2.bin bs=1024 count=1024
      git add blob*.bin
      git commit -m "Adding files"
      source "$ENVRC"
      git push origin master
      git remote -v
    ) && cd ..
  git clone --progress fake-remote-repo local-repo-dup &&\
    cd local-repo-dup && (
      git lfs install --local
      git config --add lfs.customtransfer.lfs-s3.path ../../lfs-s3.sh
      git config --add lfs.standalonetransferagent lfs-s3
      git config --add lfs.concurrenttransfers 2
      source "$ENVRC"
      git reset --hard master
      git lfs pull
    )
)
