# Test How to Load Shared Shell Env Vars

## Background

While working on the NCI WQ pipeline (the globus part, specifically), I wanted
to shared certain bits of information like the globus UUIDs for Sherlock and
Oak with multiple scripts so that I don't have them repeated in multiple places.

What I have tried so far is that simply `source`ing another shell script with
environment variable defined is insufficient to allow those variables to be
imported.

## Hypothesis:

I expect that `export`ing these variables will make them available to the
calling script.

## Results

`export`ing is not needed; regular `source`ing works fine!  The thing is that I
need to be careful about relative/absolute filepaths and other things
tangentially related to loading the file itself.

