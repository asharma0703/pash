#!/usr/bin/env bash

set -e

cd $(dirname $0)
# check the git status of the project
if git rev-parse --git-dir > /dev/null 2>&1; then
    # we have cloned from the git repo, so all the .git related files/metadata are available
    git submodule init
    git submodule update
    # set PASH_TOP
    PASH_TOP=${PASH_TOP:-$(git rev-parse --show-toplevel)}
else
    # set PASH_TOP to the root folder of the project if it is not available
    PASH_TOP=${PASH_TOP:-$PWD/..}
    # remove previous installation if it exists
    rm -rf $PASH_TOP/compiler/parser/libdash
    # we are in package mode, no .git information is available
    git clone https://github.com/angelhof/libdash/ $PASH_TOP/compiler/parser/libdash
fi
cd $PASH_TOP

LOG_DIR=$PASH_TOP/install_logs
mkdir -p $LOG_DIR
PYTHON_PKG_DIR=$PASH_TOP/python_pkgs
# remove the folder in case it exists
rm -rf $PYTHON_PKG_DIR
# create the new folder
mkdir -p $PYTHON_PKG_DIR

echo "Building parser..."
cd compiler/parser

if type lsb_release >/dev/null 2>&1 ; then
    distro=$(lsb_release -i -s)
elif [ -e /etc/os-release ] ; then
    distro=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release)
fi

echo "|-- making libdash..."
# convert to lowercase
distro=$(printf '%s\n' "$distro" | LC_ALL=C tr '[:upper:]' '[:lower:]')
# save distro in the init file
echo "export distro=$distro" > ~/.pash_init
# now do different things depending on distro
case "$distro" in
    freebsd*) 
        gsed -i 's/ make/ gmake/g' Makefile
        gmake libdash &> $LOG_DIR/make_libdash.log
        echo "Building runtime..."
        # Build runtime tools: eager, split
        cd ../../runtime/
        gmake &> $LOG_DIR/make.log
        ;;
    *)
        make libdash &> $LOG_DIR/make_libdash.log
        echo "Building runtime..."
        # Build runtime tools: eager, split
        cd ../../runtime/
        make &> $LOG_DIR/make.log
        # if the script is spawned from docker
        # export the required env variables
        # this addresses all the Linux distro variants
        if [[ $PASH_HOST == "docker" ]]; then
            # issue with docker only
            python3 -m pip install -U --force-reinstall pip
            cp /opt/pash/pa.sh /usr/bin/
            # add to the bashrc
            echo "export PASH_TOP=/opt/pash" >> ~/.bashrc
            # export to the local pash configuration file
            echo "export LC_ALL=en_US.UTF-8" >> ~/.pash_init
            echo "export LANG=en_US.UTF-8" >> ~/.pash_init
            echo "export LANGUAGE=en_US.UTF-8" >> ~/.pash_init
        fi
        ;;
esac

## This was the old parser installation that required opam.
# # Build the parser (requires libtool, m4, automake, opam)
# echo "Building parser..."
# eval $(opam config env)
# cd compiler/parser
# echo "|-- installing opam dependencies..."
# make opam-dependencies &> $LOG_DIR/make_opam_dependencies.log
# echo "|-- making libdash... (requires sudo)"
# ## TODO: How can we get rid of that `sudo make install` in here?
# make libdash &> $LOG_DIR/make_libdash.log
# make libdash-ocaml &>> $LOG_DIR/make_libdash.log
# echo "|-- making parser..."
# make &> $LOG_DIR/make.log
# cd ../../

cd ../

echo "Installing python dependencies..."
python3 -m pip install jsonpickle --root $PYTHON_PKG_DIR --ignore-installed #&> $LOG_DIR/pip_install_jsonpickle.log
python3 -m pip install pexpect --root $PYTHON_PKG_DIR --ignore-installed #&> $LOG_DIR/pip_install_pexpect.log
python3 -m pip install numpy --root $PYTHON_PKG_DIR --ignore-installed #&> $LOG_DIR/pip_install_numpy.log
python3 -m pip install matplotlib --root $PYTHON_PKG_DIR --ignore-installed #&> $LOG_DIR/pip_install_matplotlib.log
# clean the python packages
cd $PYTHON_PKG_DIR
# can we find a better alternative to that                                      
pkg_path=$(find . \( -name "site-packages" -or -name "dist-packages" \) -type d)
mv ${pkg_path}/* ${PYTHON_PKG_DIR}/                                             

echo "Generating input files..."
$PASH_TOP/evaluation/tests/input/setup.sh

# export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib/"
echo " * * * "
echo "Do not forget to export PASH_TOP before using pash: \`export PASH_TOP=$PASH_TOP\`"
echo '(optionally, you can update PATH to include it: `export PATH=$PATH:$PASH_TOP`)'
echo " * * * "
## append PASH Configuration paths to the respective rc files
rc_configs=(~/.shrc ~/.bashrc  ~/.zshrc ~/.cshrc ~/.kshrc) # add more shell configs here
for config in "${rc_configs[@]}"
do
    ## if the config exists
    ## check if it contains an old entry of Pash
    if [ -e "$config" ]; then
        # get the shell name
        shell_name=$(echo $(basename $config) | sed 's/rc//g' | sed 's/\.//g')
        echo "Do you want to append \$PASH_TOP to $shell_name ($config) (y/n)?"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ] ;then 
            tmpfile=$(mktemp -u /tmp/tmp.XXXXXX)
            # create a backup of the shell config
            cp $config ${config}.backup
            # remove all the entries pointing to PASH_TOP and PATH
            cat $config | grep -v -e "export PASH_TOP" -e "export PATH" > $tmpfile
            mv $tmpfile $config
            ## there isn't a previous Pash installation, append the configuration
            echo "export PASH_TOP="$PASH_TOP >> $config
            echo "export PATH="$PATH:$PASH_TOP >> $config
        fi
    fi
done
