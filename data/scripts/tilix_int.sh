#!/bin/bash
# Adapted from vte.sh script, copyright notice from that ensues:

# Copyright © 2006 Shaun McCance <shaunm@gnome.org>
# Copyright © 2013 Peter De Wachter <pdewacht@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
if [ -z ${HOSTNAME+x} ]
then
  HOSTNAME=$(hostname)
fi
# Not bash or zsh?
[ -n "$BASH_VERSION" -o -n "$ZSH_VERSION" ] || return 0

# Not an interactive shell?
[[ $- == *i* ]] || return 0

__tilix_urlencode() (
  # This is important to make sure string manipulation is handled
  # byte-by-byte.
  LC_ALL=C
  str="$1"
  while [ -n "$str" ]; do
    safe="${str%%[!a-zA-Z0-9/:_\.\-\!\'\(\)~]*}"
    printf "%s" "$safe"
    str="${str#"$safe"}"
    if [ -n "$str" ]; then
      printf "%%%02X" "'$str"
      str="${str#?}"
    fi
  done
)

__tilix_osc7() (
  printf "\033]7;file://%s%s\007" "${HOSTNAME:-}" "$(__tilix_urlencode "${PWD}")"
)

if [[ $PROMPT_COMMAND != *"__vte_prompt_command"* ]]
then
    if [ "$TILIX_SILENT" != "1" ]; then
        echo "Adding tilix osc7"
    fi
    [ -n "$BASH_VERSION" ] && PROMPT_COMMAND="__tilix_osc7"
    [ -n "$ZSH_VERSION"  ] && precmd_functions+=(__tilix_osc7)
fi
