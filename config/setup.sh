#!/bin/bash

echo "[SETUP] Initial setup of a bare git repository and a code working copy"

rm -rf repo.git 
rm -rf check code 
# rm -rf perl5

mkdir repo.git   # bare git repository
mkdir check      # working copy to check update
mkdir code       # working copy
mkdir perl5      # locally installed CPAN modules

# perl -Mlocal::lib >> .bashrc

cd repo.git
git init --bare

# update hook is called before update, so it can reject pushing
HOOK=hooks/update
echo "[SETUP] create repo.git/$HOOK"
cat >$HOOK <<'HOOK'
#!/bin/bash

refname="$1"
oldrev="$2"
newrev="$3"

if [ -z "$refname" -o -z "$oldrev" -o -z "$newrev" ]; then
    echo "Usage: $0 <ref> <oldrev> <newrev>" >&2
    exit 1
fi

# Any command that fails will cause the entire script to fail
set -e

export GIT_WORK_TREE=~/check
export GIT_DIR=~/repo.git
echo "[UPDATE] Checking out in $GIT_WORK_TREE to install dependencies"

cd $GIT_WORK_TREE
git checkout -q -f $newrev

cpanm --local-lib ~/perl5 --installdeps ./gbvdoc/

# TODO: run make test

exit $?
HOOK
chmod +x $HOOK

# post-receive hook actually installs the new revision
HOOK=hooks/post-receive
echo "[SETUP] create repo.git/$HOOK"
cat >$HOOK <<'HOOK'
#!/bin/bash

export GIT_WORK_TREE=~/code
export GIT_DIR=~/repo.git

cd $GIT_WORK_TREE && git checkout -f

PIDFILE=/tmp/gbvdoc-starman.pid
if [ -f $PIDFILE ]; then
    PROCESS=`cat $PIDFILE`
    echo "Gracefully restarting starman web server (process $PROCESS)"
    kill -HUP $PROCESS
else
    echo "$PIDFILE not found, no restart forced!"
fi
HOOK
chmod +x $HOOK

cd ..
