#!/usr/bin/env bash

PLATFORM='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
   PLATFORM='linux'
elif [[ "$unamestr" == 'FreeBSD' ]]; then
   PLATFORM='freebsd'
elif [[ "$unamestr" == 'Darwin' ]]; then
    PLATFORM='osx'
elif [[ "$unamestr" == *"MINGW"* ]]; then
	PLATFORM='windows'
fi

arch=x86
if [[ $HOSTTYPE == x86_64 ]]; then
    arch=x64
fi

# Set this to whatever you use to call a lua runtime on the command line. I've been using a locally built luajit 
# runtime for mine. I've also been using Love2D compiled against Luajit 2.1-beta2 as well as Luapower, but that's 
# neither here nor there.
lua=luajit

startdir=$PWD

echo -- Arch = $arch
echo -- Lua = $lua
echo -- Starting in $startdir
echo

for file in Profiler/Results/*-result.txt ; do
	rm $file
done

$lua profile.lua classy classes
echo

$lua profile.lua middleclass classes
echo

$lua profile.lua classy alloc
echo

$lua profile.lua middleclass alloc
echo

$lua profile.lua classy methods
echo

$lua profile.lua middleclass methods
echo

$lua profile.lua classy inheritance-alloc
echo

$lua profile.lua middleclass inheritance-alloc
echo

$lua profile.lua classy inheritance-methods
echo

$lua profile.lua middleclass inheritance-methods
echo
