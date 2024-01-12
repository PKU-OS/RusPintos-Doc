#!/bin/sh

export PATH=$PATH:$(pwd)

curl -L https://github.com/rust-lang/mdBook/releases/download/v0.4.35/mdbook-v0.4.35-x86_64-unknown-linux-gnu.tar.gz | tar xvz &&
curl -L https://github.com/tommilligan/mdbook-admonish/releases/download/v1.15.0/mdbook-admonish-v1.15.0-x86_64-unknown-linux-gnu.tar.gz | tar xvz &&
mdbook build
