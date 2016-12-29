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

iterations=500000

echo Profiling Classy Classes Memory
$lua profile.lua classy classes $iterations
echo

echo Profiling Middleclass Classes Memory
$lua profile.lua middleclass classes $iterations
echo

echo Profiling Classy Allocation
$lua profile.lua classy allocation $iterations
echo

echo Profiling Middleclass Allocation
$lua profile.lua middleclass allocation $iterations
echo

echo Profiling Classy Method Invocation
$lua profile.lua classy methods $iterations
echo

echo Profiling Middleclass Method Invocation
$lua profile.lua middleclass methods $iterations
echo

echo Profiling Classy Subclass Allocation
$lua profile.lua classy inheritance-allocation $iterations
echo

echo Profiling Middleclass Subclass Allocation
$lua profile.lua middleclass inheritance-allocation $iterations
echo

echo Profiling Classy Subclass Method Invocation
$lua profile.lua classy inheritance-methods $iterations
echo

echo Profiling Middleclass Subclass Method Invocation
$lua profile.lua middleclass inheritance-methods $iterations
echo
