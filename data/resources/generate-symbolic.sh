#!/usr/bin/env sh

echo "Creating PNG symbolic resource icons"
mkdir -p icons/16x16/actions
mkdir -p icons/32x32/actions

find icons -type f -name "*.symbolic.png" -delete

gtk-encode-symbolic-svg -o icons/16x16/actions icons/scalable/actions/terminix-add-horizontal-symbolic.svg 16x16
gtk-encode-symbolic-svg -o icons/16x16/actions icons/scalable/actions/terminix-add-vertical-symbolic.svg 16x16
gtk-encode-symbolic-svg -o icons/32x32/actions icons/scalable/actions/terminix-add-horizontal-symbolic.svg 32x32
gtk-encode-symbolic-svg -o icons/32x32/actions icons/scalable/actions/terminix-add-vertical-symbolic.svg 32x32
