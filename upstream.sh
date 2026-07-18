#!/usr/bin/env bash

git remote add upstream https://github.com/cotes2020/chirpy-starter.git
git fetch upstream
git checkout main
git merge upstream/main

git submodule update --init --recursive
git submodule update --recursive --remote
