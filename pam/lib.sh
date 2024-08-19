#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/pam/Library/basic
#   Description: What the test does
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = pam
#   library-version = 14
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_pam_LIB_NAME="pam/basic"
__INTERNAL_pam_LIB_VERSION=14

echo -n "loading library $__INTERNAL_pam_LIB_NAME v$__INTERNAL_pam_LIB_VERSION... "

__INTERNAL_pam_d=1
[[ -d /etc/pam.d ]] && __INTERNAL_pam_d=''
__INTERNAL_pam_path='/etc/pam.conf'
[[ -z "$__INTERNAL_pam_d" ]] && {
  __INTERNAL_pam_path='/etc/pam.d'
}

: <<'=cut'
=pod

=head1 NAME

pam/basic - Basic functions to support pam configuration

=head1 DESCRIPTION

This library provides function for manipulation with the pam config files.


=head1 FUNCTIONS

=cut


__INTERNAL_pam_filename() {
  local SERVICE="$1"
  local filename="$__INTERNAL_pam_path"
  if [[ -z "$__INTERNAL_pam_d" ]]; then
    filename="$__INTERNAL_pam_path/$SERVICE"
  fi
  echo -n "$filename"
}


__INTERNAL_pam_prefix() {
  local SERVICE="$1"
  local TYPE="$2"
  echo -n ${__INTERNAL_pam_d:+"${SERVICE}\s+"}
  echo -n ${TYPE:+"-?${TYPE}\s+"}
}


__INTERNAL_pam_get_file_content_iterate() {
  local SERVICE="$1" TYPE="$2"
  local first='' pam_A='' pam_B='' pam_C='' line
  local LF='
'
  local pam_conf_file="$(__INTERNAL_pam_filename "$SERVICE")"
  __INTERNAL_pam_files="${__INTERNAL_pam_files}${pam_conf_file}${LF}"
  local regex="^[^:]*:$(__INTERNAL_pam_prefix "$SERVICE" "$TYPE")" regexp2=''
  while read line; do
    line="${pam_conf_file}:${line}"
    if [[ "$line" =~ $regex ]]; then
      first=1
      regexp2="${regexp}(include|substack)\s+(\S+)"
      if [[ "$line" =~ $regexp2 ]]; then
        __INTERNAL_pam_B="${__INTERNAL_pam_B}${pam_C}${line}${LF}"
        __INTERNAL_pam_get_file_content_iterate "${BASH_REMATCH[2]}" "$TYPE"
      else
        # if matched again, so copy third part to the second one
        __INTERNAL_pam_B="${__INTERNAL_pam_B}${pam_C}${line}${LF}"
      fi
      # and clean the third
      pam_C=''
    elif  [[ -z "$first" ]]; then
      # before first match
      pam_A="${pam_A}${line}${LF}"
    else
      # not matched (may be after last match)
      pam_C="${pam_C}${line}${LF}"
    fi
  done < $pam_conf_file
  __INTERNAL_pam_A="${__INTERNAL_pam_A}${pam_A}"
  __INTERNAL_pam_C="${__INTERNAL_pam_C}${pam_C}"
}

__INTERNAL_pam_get_file_content() {
  local SERVICE="$1" TYPE="$2"
  __INTERNAL_pam_A='' __INTERNAL_pam_B='' __INTERNAL_pam_C='' __INTERNAL_pam_files=''
  __INTERNAL_pam_get_file_content_iterate "$SERVICE" "$TYPE"
  __INTERNAL_pam_linecount=$(echo "$__INTERNAL_pam_B" | wc -l)
  `LogVar __INTERNAL_pam_A __INTERNAL_pam_B __INTERNAL_pam_C`
}


__INTERNAL_pam_set_files_content() {
  local line file content
  echo "$__INTERNAL_pam_files" | sort | uniq | while read line; do
    [[ -z "$line" ]] && continue
    LogMore -f "cleaning file '$line'"
    > "$line"
  done

  `LogVar __INTERNAL_pam_A __INTERNAL_pam_B __INTERNAL_pam_C`
  {
    echo "$__INTERNAL_pam_A"
    echo "$__INTERNAL_pam_B"
    echo "$__INTERNAL_pam_C"
  } | while read line; do
    file="$(echo "$line" | cut -d : -f 1)"
    if [[ -n "$file" ]]; then
      content="$(echo "$line" | cut -d : -f 2-)"
      LogMore_ -f "writing '$content' to '$file'"
      echo "$content" >> "$file"
    fi
  done
}


# __INTERNAL_pam_parse_file ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_pam_parse_file() {
  __INTERNAL_pam_get_file_content "$@"
}; # end of __INTERNAL_pam_parse_file }}}


# pamInsertServiceRule ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamInsertServiceRule

Insert new row to the respective pam config file.

    pamInsertServiceRule SERVICE TYPE CONTROL MODULE_PATH [MODULE_ARGUMENTS [ROW]]

Paratemer names are used the same as in pam manual pages. For more details refer
man pam or man pam.conf.

=over

=item SERVICE

Ususaly name of the file in /etc/pam.d.

=item TYPE

Like account, auth, session and password.

=item CONTROL

Like sufficient, reqiured, ...

=item MODULE_PATH

Usualy file name of the module, like pam_unix.so.

=item MODULE_ARGUMENTS

If no agruments are required, use empty string ('').

=item ROW

Furute ROW number in the TYPE paragraph of the SERVICE.

   1 - insert as the very first row
   2 - insert as the second row
  ...
  -2 - insert as the second row from the end
  -1 - insert as the very last row

  Default is 1.

=back

=cut

pamInsertServiceRule() {
  local SERVICE="$1" TYPE="$2" CONTROL="$3" MODULE_PATH="$4" MODULE_ARGUMENTS="$5" ROW="${6:-"1"}"
  `LogVar SERVICE TYPE CONTROL MODULE_PATH MODULE_ARGUMENTS ROW`
  local LF='
'
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  local tmp='' num=1 file
  [[ "${ROW:0:1}" == '-' ]] && let ROW=$__INTERNAL_pam_linecount$ROW+1
  `LogVar ROW`
  [[ $ROW -lt 1 || $ROW -gt $__INTERNAL_pam_linecount ]] && {
    echo "ROW index out of range" >&2
    return 1
  }
  while read line; do
    LogMore -f "processing line $num, containing '$line'"
    [[ -n "$line" ]] && file="$(echo "$line" | cut -d : -f 1)"
    [[ $num -eq $ROW ]] && {
      LogDebug -f "adding new line '$file:${__INTERNAL_pam_d:+"$SERVICE    "}$TYPE    $CONTROL    $MODULE_PATH${MODULE_ARGUMENTS:+" $MODULE_ARGUMENTS"}' to row $num"
      tmp="$tmp$file:${__INTERNAL_pam_d:+"$SERVICE    "}$TYPE    $CONTROL    $MODULE_PATH${MODULE_ARGUMENTS:+" $MODULE_ARGUMENTS"}$LF"
    }
    let num++
    [[ $num -le $__INTERNAL_pam_linecount ]] && tmp="$tmp$line$LF"
  done <<< "$__INTERNAL_pam_B"
  __INTERNAL_pam_B="$tmp"
  __INTERNAL_pam_set_files_content
}; # end of pamInsertServiceRule }}}


# pamDeleteServiceRule ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamDeleteServiceRule

Delete a row from the respective pam config file.

    pamDeleteServiceRule SERVICE TYPE ROW

=over

=item ROW

A ROW number which wioll be deleted from the TYPE paragraph of the SERVICE.

For more details about ROW refer to I<pamInsertServiceTypeRule>.

=back

=cut

pamDeleteServiceRule() {
  local SERVICE="$1" TYPE="$2" ROW="$3"
  local LF='
'
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  local tmp='' num=1
  [[ "${ROW:0:1}" == '-' ]] && let ROW=$__INTERNAL_pam_linecount$ROW
  [[ $ROW -lt 1 || $ROW -ge $__INTERNAL_pam_linecount ]] && {
    echo "ROW index out of range" >&2
    return 1
  }
  while read line; do
    [[ $num -lt $__INTERNAL_pam_linecount && $num -ne $ROW ]] && tmp="$tmp$line$LF"
    let num++
  done < <(echo "$__INTERNAL_pam_B")
  __INTERNAL_pam_B="$tmp"
  __INTERNAL_pam_set_files_content
}; # end of pamDeleteServiceRule }}}


# pamDeleteServiceModuleRule ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamDeleteServiceModuleRule

Delete a row from the respective pam config file based on the pattern.

    pamDeleteServiceModuleRule SERVICE TYPE MODULE_PATH [MODULE_ARGUMENTS]

    The pattern is treated as regular expression and is composed as follows:
    ${TYPE}\s+\S+\s+${MODULE_PATH}
    If MODULE_ARGUMENTS is present the pattern is exetended to
    ${TYPE}\s+\S+\s+${MODULE_PATH}\s+${MODULE_ARGUMENTS}

=cut

pamDeleteServiceModuleRule() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3" tmp MODULE_ARGUMENTS="$4"
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  tmp="$(echo -n "$__INTERNAL_pam_B" | sed -r "/^[^:]+:${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+${MODULE_PATH}${MODULE_ARGUMENTS:+\s+$MODULE_ARGUMENTS}/d")"
  __INTERNAL_pam_B="$tmp"
  __INTERNAL_pam_set_files_content
}; # end of pamDeleteServiceModuleRule }}}


# pamReplaceServiceModuleRule ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamReplaceServiceModuleRule

Replace a row from the respective pam config file based on the pattern.

    pamReplaceServiceModuleRule SERVICE TYPE MODULE_PATH MODULE_ARGUMENTS NEW_CONTROL NEW_MODULE_PATH [NEW_MODULE_ARGUMENTS]

    The pattern is treated as regular expression and is composed as follows:
    ${TYPE}\s+\S+\s+${MODULE_PATH}
    If MODULE_ARGUMENTS is non-empty the pattern is exetended to
    ${TYPE}\s+\S+\s+${MODULE_PATH}\s+${MODULE_ARGUMENTS}

=cut

pamReplaceServiceModuleRule() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3" MODULE_ARGUMENTS="$4"
  local NEW_CONTROL="$5" NEW_MODULE_PATH="$6" NEW_MODULE_ARGUMENTS="${7:+" $7"}" tmp
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  LogMore -f "sed pattern: s/^([^:]+:)${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+(\\\b\S*${MODULE_PATH}\S*\\\b)\s*(${MODULE_ARGUMENTS:+\\\b\S*$MODULE_ARGUMENTS\S*\\\b}.*)/\1${__INTERNAL_pam_d:+"$SERVICE    "}${TYPE}    ${NEW_CONTROL:-"\\2"}    ${NEW_MODULE_PATH:-"\\3"}${NEW_MODULE_ARGUMENTS:-" \\4"}/"
  tmp="$(echo "$__INTERNAL_pam_B" | sed -r "s/^([^:]+:)${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+(\b\S*${MODULE_PATH}\S*\b)\s*(${MODULE_ARGUMENTS:+\\b\S*$MODULE_ARGUMENTS\S*\\b}.*)/\1${__INTERNAL_pam_d:+"$SERVICE    "}${TYPE}    ${NEW_CONTROL:-"\\2"}    ${NEW_MODULE_PATH:-"\\3"}${NEW_MODULE_ARGUMENTS:-" \\4"}/")"
  __INTERNAL_pam_B="$tmp"
  __INTERNAL_pam_set_files_content
}; # end of pamReplaceServiceModuleRule }}}


# pamReplaceServiceModuleRule2 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamReplaceServiceModuleRule2

Replace a row from the respective pam config file based on the pattern.

    pamReplaceServiceModuleRule SERVICE TYPE CONTROL MODULE_PATH MODULE_ARGUMENTS NEW_CONTROL NEW_MODULE_PATH [NEW_MODULE_ARGUMENTS]

    The pattern is treated as regular expression and is composed as follows:
    ${TYPE}\s+${CONTROL}\s+${MODULE_PATH}
    If MODULE_ARGUMENTS is non-empty the pattern is exetended to
    ${TYPE}\s+${CONTROL}\s+${MODULE_PATH}\s+${MODULE_ARGUMENTS}

\CONTROL, \MODULE_PATH, and \MODULE_ARGUMENTS can be used as keywords in
respective new parameters. These will be replaced by the original ones.

=cut

pamReplaceServiceModuleRule2() {
  local SERVICE="$1" TYPE="$2" CONTROL="$3" MODULE_PATH="$4" MODULE_ARGUMENTS="$5"
  local NEW_CONTROL="$6" NEW_MODULE_PATH="$7" NEW_MODULE_ARGUMENTS="${8:+" $8"}" tmp
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  pattern="s~^([^:]+:)${__INTERNAL_pam_d:+"$SERVICE\\s+"}${TYPE}\s+(${CONTROL:-"\\S+|\\[[^]]+\\]"})\s+((/.*/)?${MODULE_PATH}(\.so)?)\s*(${MODULE_ARGUMENTS:-".*"}\s*$)~\1${__INTERNAL_pam_d:+"$SERVICE    "}${TYPE}    ${NEW_CONTROL:-"\\2"}    ${NEW_MODULE_PATH:-"\\3"}    ${NEW_MODULE_ARGUMENTS:-" \\6"}~"
  pattern="${pattern//\\CONTROL/\\2}"
  pattern="${pattern//\\MODULE_PATH/\\3}"
  pattern="${pattern//\\MODULE_ARGUMENTS/\\6}"
  LogMore -f "sed pattern: $pattern"
  tmp="$(echo "$__INTERNAL_pam_B" | sed -r "$pattern")"
  __INTERNAL_pam_B="$tmp"
  __INTERNAL_pam_set_files_content
}; # end of pamReplaceServiceModuleRule2 }}}


# pamGetServiceRules ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamGetServiceRules

Print SERVICE TYPE paragraph

    pamGetServiceRules SERVICE TYPE

=cut

pamGetServiceRules() {
  local prefix=''
  if [[ "$1" == "--prefix" ]]; then
    prefix=1
    shift
  fi
  local SERVICE="$1" TYPE="$2"
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  if [[ -n "$prefix" ]]; then
    echo -n "$__INTERNAL_pam_B"
  elif [[ -z "$__INTERNAL_pam_d" ]]; then
    echo -n "$__INTERNAL_pam_B" | sed -r 's/^[^:]+://'
  else
    echo -n "$__INTERNAL_pam_B" | sed -r 's/^[^:]+:\S+\s+//'
  fi
}; # end of pamGetServiceRules }}}


# pamGetServiceModuleRuleRow ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 pamGetServiceModuleRuleRow

Prints row numbers from the respective pam config file holding the pattern.

    pamGetServiceModuleRuleRow SERVICE TYPE MODULE_PATH [MODULE_ARGUMENTS]

Note that you can get more then one number.
Refer to I<pamDeleteServiceModuleRule> for pattern composition.

Returns 0 if requested rule is found other wise 1.

=cut

pamGetServiceModuleRuleRow() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3"
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  local row="$(echo -n "$__INTERNAL_pam_B" | nl -w 1 -s ':' | grep -E "^[0-9]+:[^:]+:${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+${MODULE_PATH}${MODULE_ARGUMENTS:+"\s+$MODULE_ARGUMENTS"}" | cut -d ':' -f 1)"
  `LogVar row`
  echo -n "$row"
}; # end of pamGetServiceModuleRuleRow }}}


# pamGetServiceRuleAgruments {{{
: <<'=cut'
=pod

=head3 pamGetServiceRuleAgruments

Prints arguments of specified module.

    pamGetServiceRuleAgruments SERVICE TYPE MODULE_PATH [MODULE_ARGUMENTS]

Returns 0 if requested rule is found other wise 1.

=cut

pamGetServiceRuleAgruments() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3" MODULE_ARGUMENTS="$4"
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  LogMore -f "matching patter '^[^:]+:${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+\b\S*${MODULE_PATH}\S*\b\s*${MODULE_ARGUMENTS:+\b\S*$MODULE_ARGUMENTS\S*\b}'"
  local result="$(echo -n "$__INTERNAL_pam_B" | grep -P "^[^:]+:${__INTERNAL_pam_d:+"$SERVICE\s+"}${TYPE}\s+(\S+|\[[^]]+\])\s+\b\S*${MODULE_PATH}\S*\b\s*${MODULE_ARGUMENTS:+\b\S*$MODULE_ARGUMENTS\S*\b}" | sed -r 's/^[^:]+:(\S+\s*){3}//')"
  LogMore -f "mathed '$result'"
  echo "$result"
}; # end of pamGetServiceRuleAgruments }}}


# pamGetServiceRuleAgruments2 {{{
: <<'=cut'
=pod

=head3 pamGetServiceRuleAgruments2

Prints arguments of specified module.

    pamGetServiceRuleAgruments SERVICE TYPE CONTROL MODULE_PATH [MODULE_ARGUMENTS]

Empty CONTROL equals to .*

Returns 0 if requested rule is found other wise 1.

=cut

pamGetServiceRuleAgruments2() {
  local SERVICE="$1" TYPE="$2" CONTROL="$3" MODULE_PATH="$4" MODULE_ARGUMENTS="$5"
  __INTERNAL_pam_parse_file $SERVICE $TYPE

  pattern="^([^:]+:)${__INTERNAL_pam_d:+"$SERVICE\\s+"}${TYPE}\s+(${CONTROL:-"\\S+|\\[[^]]+\\]"})\s+((/.*/)?${MODULE_PATH}(\.so)?)\s*(${MODULE_ARGUMENTS:-".*"}\s*$)"
  sed_pattern="s~$pattern~\\6~"
  LogMore -f "matching patter '$pattern'"
  LogMore -f "sed patter '$sed_pattern'"
  local result="$(echo -n "$__INTERNAL_pam_B" | grep -P "$pattern" | sed -r "$sed_pattern")"
  LogMore -f "mathed '$result'"
  echo "$result"
}; # end of pamGetServiceRuleAgruments2 }}}


# pamInsertServiceRuleAfter {{{
: <<'=cut'
=pod

=head3 pamInsertServiceRuleAfter

Insert rule after a row from the respective pam config file based on the pattern.

    pamInsertServiceRuleAfter SERVICE TYPE MODULE_PATH MODULE_ARGUMENTS NEW_CONTROL NEW_MODULE_PATH [NEW_MODULE_ARGUMENTS]

    The pattern is treated as regular expression and is composed as follows:
    ${TYPE}\s+\S+\s+${MODULE_PATH}
    If MODULE_ARGUMENTS is non-empty the pattern is exetended to
    ${TYPE}\s+\S+\s+${MODULE_PATH}\s+${MODULE_ARGUMENTS}

Returns 0 if success.

=cut

pamInsertServiceRuleAfter() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3" MODULE_ARGUMENTS="$4"
  local NEW_CONTROL="$5" NEW_MODULE_PATH="$6" NEW_MODULE_ARGUMENTS="$7"
  local ROW=$(pamGetServiceModuleRuleRow "$SERVICE" "$TYPE" "$MODULE_PATH" "$MODULE_ARGUMENTS")
  pamInsertServiceRule "$SERVICE" "$TYPE" "$NEW_CONTROL" "$NEW_MODULE_PATH" "$NEW_MODULE_ARGUMENTS" "$((++ROW))"
}; # end of pamInsertServiceRuleAfter }}}


# pamInsertServiceRuleAfter {{{
: <<'=cut'
=pod

=head3 pamInsertServiceRuleBefore

Insert rule before a row from the respective pam config file based on the pattern.

    pamInsertServiceRuleBefore SERVICE TYPE MODULE_PATH MODULE_ARGUMENTS NEW_CONTROL NEW_MODULE_PATH [NEW_MODULE_ARGUMENTS]

    The pattern is treated as regular expression and is composed as follows:
    ${TYPE}\s+\S+\s+${MODULE_PATH}
    If MODULE_ARGUMENTS is non-empty the pattern is exetended to
    ${TYPE}\s+\S+\s+${MODULE_PATH}\s+${MODULE_ARGUMENTS}

Returns 0 if success.

=cut

pamInsertServiceRuleBefore() {
  local SERVICE="$1" TYPE="$2" MODULE_PATH="$3" MODULE_ARGUMENTS="$4"
  local NEW_CONTROL="$5" NEW_MODULE_PATH="$6" NEW_MODULE_ARGUMENTS="$7"
  local ROW=$(pamGetServiceModuleRuleRow "$SERVICE" "$TYPE" "$MODULE_PATH" "$MODULE_ARGUMENTS")
  pamInsertServiceRule "$SERVICE" "$TYPE" "$NEW_CONTROL" "$NEW_MODULE_PATH" "$NEW_MODULE_ARGUMENTS" "$ROW"
}; # end of pamInsertServiceRuleBefore }}}


# pamSetup {{{
: <<'=cut'
=pod

=head3 pamSetup

Save current pam state.

Returns 0 if success.

=cut

pamSetup() {
  pamBackupFiles
}; # end of pamSetup }}}


# pamCleanup {{{
: <<'=cut'
=pod

=head3 pamCleanup

Restore state as it was before pamSetup

Returns 0 if success.

=cut

pamCleanup() {
  pamRestoreFiles
}; # end of pamCleanup }}}


# pamBackupFiles {{{
: <<'=cut'
=pod

=head3 pamBackupFiles

Backup pam config files, optionally under user-defined namespace.

    pamBackupFiles [namespace]

Returns 0 if success.

=cut

pamBackupFiles() {
  rlRun "rlFileBackup --namespace ${1:-pam-lib} --clean /etc/pam.d $(readlink -m /etc/pam.d/* | tr '\n\r' '  ') /etc/pam.conf $(readlink -m /etc/pam.conf | tr '\n\r' '  ') /etc/security $(readlink -m  /etc/security/* | tr '\n\r' '  ')" 0,8
}; # end of pamBackupFiles }}}


# pamRestoreFiles {{{
: <<'=cut'
=pod

=head3 pamRestoreFiles

    pamRestoreFiles [namespace]

Restore files backed in pamBackupFiles up, optionally under user-defined
namespace.

Returns 0 if success.

=cut

pamRestoreFiles() {
  rlRun "rlFileRestore --namespace ${1:-pam-lib}" 0
}; # end of pamRestoreFiles }}}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

pamLibraryLoaded() {
    if rpm=$(rpm -q pam); then
        rlLogDebug "Library pam/basic running with $rpm"
        return 0
    else
        rlLogError "Package pam not installed"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo "done."
