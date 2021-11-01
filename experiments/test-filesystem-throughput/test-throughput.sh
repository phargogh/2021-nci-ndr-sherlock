#!/bin/bash
#
#SBATCH --time=00:02:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#
# Script to test throughput of a filesystem
# Adapted from https://docs.gitlab.com/ee/administration/operations/filesystem_benchmarking.html#simple-benchmarking

# Assume that parameter 1 is the target filesystem
cd $1
echo "Testing on the filesystem $1"
TEST_DIR="test"
mkdir $TEST_DIR
pushd $TEST_DIR

# Test write: small files
echo "small files write"
time for i in {0..1000}; do echo 'test' > "test${i}.txt"; done

# test read
echo "small files read"
time for i in {0..1000}; do cat "test${i}.txt" > /dev/null; done

echo "large file write"
FILENAME=1GB-random-data.txt
time openssl rand -out $FILENAME -base64 $(( 2**30 * 3/4 ))

echo "large file read"
time cat $FILENAME > /dev/null

rm -r $TEST_DIR
