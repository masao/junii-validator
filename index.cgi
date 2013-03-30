#!/bin/sh
### wrapper script for SAKURA environment.
export HOME=$DOCUMENT_ROOT/..
export GEM_HOME=$HOME/.gem
echo "Content-Type: text/plain"
exec ./index.rb "$@"
