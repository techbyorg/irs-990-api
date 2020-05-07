#!/bin/sh
export LINT=0
export COVERAGE=0

node_modules/gulp/bin/gulp.js watch
