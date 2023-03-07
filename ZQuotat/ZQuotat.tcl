#################################################################################
# ngBot - ZQuotat.tcl
#################################################################################
#
# Description:
# - Auto announces the top quotat uploaders at a configurable interval.
#
# Installation:
# 1. Add the following to your eggdrop.conf:
#    source pzs-ng/plugins/ZQuota.tcl
#
# 2. Rehash or restart your eggdrop for the changes to take effect.
#
#
#################################################################################

namespace eval ::ngBot::plugin::ZQuota {
  variable ns                   [namespace current]
  variable np                   [namespace qualifiers [namespace parent]]
  package require ZarTek-Tools 0.1
  variable quotat
  variable hidden

  # TODO: #1 separate all config settings into a separate file
  ## Config Settings ###############################
  ##
  ## Interval between announces in seconds (default: 7200 - 2 hours)
  set quotat(interval)          7200
  ##
  ## Section to display (0 = DEFAULT)
  set quotat(sect)              0
  # /home/glftpd/bin/stats -r /home/glftpd/etc/glftpd.conf -u -w -x 30 -s 0 -x ${quotat(users_limit)} -g glftpd -g SiteOP -g Admin -g Friends -g NUKERS -g VACATION

  # Users to hide in the list
  set hidden(users)             "Billy"

  # Groups to hide in the list
  set hidden(groups)            "glftpd SiteOP Admin Friends NUKERS VACATION"

  ## Maximum number of users to display
  set quotat(users_limit)       100

  ## Flag to set when user is deleted
  set quotat(set_flag)          6

  # Quota to pass (in GB)
  set quotat(for_pass)          250


  ## Prefix in header to use for the announce (default: "Top uploaders this week (Quota)")
  set quotat(prefix)            "Top uploaders de la semaine (Quotat)"

  ## Channel to announce in (default: "#glftpd")
  set quotat(chan)              "#glftpd"

  ## Channel to announce in (default: "#glftpd-staff")
  set quotat(chanlog)           "#glftpd-staff"

  ## Command to trigger the announce (default: "!top")
  set cmds(trigger)             "!top"

  variable timer
  ##
  ##################################################

  set quotat(version)           "20230323"
  set script(version)           "0.1"
  set script(date)              "2023-03-23"
  proc Trigger { nick host nick2 chan_source args } {
    variable ns
    variable np
    variable quotat
    variable hidden
    variable ${np}::binary
    variable ${np}::location
    set STATS_EXEC              "${binary(STATS)} -r ${location(GLCONF)} -u -w -x ${quotat(users_limit)} -s ${quotat(sect)}"
    append STATS_EXEC           [join "{} ${hidden(groups)}" " -g "]
    append STATS_EXEC           [join "{} ${hidden(users)}" " -e "]
    if {[catch {eval exec ${STATS_EXEC}} output] != 0} {
      putlog "\[ngBot\] ${ns} :: Error: Problem executing stats-exec \"${output}\""
      return
    }
    if { [string match -nocase "*-del*" ${args}] } {

      if { [clock format [clock scan "+1 day +1 hour" -base [clock seconds]] -format %V] != [clock format [clock seconds] -format %V] } {
        set delneed             1
      } else {
        set delneed             0
      }
    } else {
      set delneed               0
    }

    sentmsg ${chan_source} "\00312[TXT:ESPACE:DISPLAY "${quotat(prefix)}" 75]"
    set QUOTA_NEED              [expr ${quotat(for_pass)} * 1024 * 1024]
    set quotat_need             [${np}::format_kb ${QUOTA_NEED}]
    set p_num                   1
    foreach line [split ${output} "\n"] {
      regsub -all -- {(\s+)\s} ${line} " " line

      if {[regexp -- {^\[(\d+)\]\s+(.*?)\s+(.*?)\s+(\d+)\s+(\d+)(\S+)\s+(\S+)} ${line} -> pos username tagline files bytes units speed]} {
        set size                [ConverSizeToBytes ${bytes} ${units}]
        set mbytes              [${np}::format_kb ${size}]
        set missing_size        [${np}::format_kb [expr ${QUOTA_NEED} - ${size}]]
        set userfile            "${location(USERS)}${username}"
        set GROUP               [lindex [${np}::USERFILE:GETINFO ${username} GROUP] 0]
        set FLAGS_NOW           [lindex [${np}::USERFILE:GETINFO ${username} FLAGS] 0]
        set ADDED_TIME          [lindex [${np}::USERFILE:GETINFO ${username} ADDED] 0]
        set FLAGS_NEW           "${FLAGS_NOW}${quotat(set_flag)}"

        # user have allready flags deleted , no show
        if { [string match "*${quotat(set_flag)}*" ${FLAGS_NOW}] } {
          # sentmsg ${quotat(chanlog)} "Quotat: User '${username}' already deleted."
          continue

        }

        if { [isquotatpassed ${bytes}] } {
          set TEXT              "\00310Gagné !\003 "
          set COLOR             "\00310"
          set isquotatpassed    1
        } else {
          set TEXT              "\00304(Encore: ${missing_size})\003 "
          set COLOR             "\00304"
          set isquotatpassed    0
        }
        set position_number [format "%03d" ${p_num}]
        set MESSAGE             "\[ \00312${position_number}\003. "
        append MESSAGE          "\00307[TXT:ESPACE:DISPLAY ${username} 15]\003 "
        append MESSAGE          "\00314@"
        append MESSAGE          "\00307[TXT:ESPACE:DISPLAY ${GROUP} 10]\003 "
        append MESSAGE          "${COLOR}[TXT:ESPACE:DISPLAY "${mbytes}" 10]\00314/\00312[TXT:ESPACE:DISPLAY "${quotat_need}" 10] "
        append MESSAGE          [TXT:ESPACE:DISPLAY "${text}" 25]
        append MESSAGE          "\] "
        incr p_num
        sentmsg ${chan_source} "${MESSAGE}"
        # 604800 = on week, new user is passed
        if { !${isquotatpassed} \
          && ${delneed}         \
          && [expr [clock seconds]-${ADDED_TIME}] < 604800
      } {
        ${np}::String:Replace:InFile ${userfile} "FLAGS ${FLAGS_NOW}" "FLAGS ${FLAGS_new}"
        sentmsg ${quotat(chanlog)} "User ${username} is deleted, quotat missing -> ${missing_size} :("
      }
    }
  }
  return 1
}

proc isquotatpassed { user_size } {
  variable quotat
  if { ${quotat(for_pass)} < ${user_size} } { return 1 }
  return 0
}
proc ConverSizeToBytes { Numbers Unit } {
  if { [string match -nocase "GiB" ${Unit}] } { return [expr ${Numbers} * 1024 * 1024] }
  return ${Numbers}
}


proc sentmsg {dest text} {
  foreach chan [split ${dest}] {
    putnow "PRIVMSG ${chan} :${text}"
  }
}
proc init {args} {
  variable ns
  variable np
  variable quotat
  variable cmds
  variable script
  [namespace current]::startTimer
  if {([info exists cmds(trigger)]) && (![string equal ${cmds(trigger)} ""])} {
    bind pub -|- ${cmds(trigger)} ${ns}::Trigger
  }
  bind time - "59 23 * * *" ${ns}::time:proc
  ${np}::logsuccess "Loaded successfully (Version: ${script(version)} - ${script(date)})." ${ns}
}
proc time:proc { min hour day month year } {
  variable ns
  variable quotat
  ${ns}::Trigger "" "" "" ${quotat(chan)} "-del"
}
proc deinit {args} {
  [namespace current]::killTimer
  catch {unbind pub -|- ${cmds(trigger)} ${ns}::Trigger}
  catch {unbind time - "59 23 * * *" ${ns}::time:proc}
  # namespace delete [namespace current]
}

proc killTimer {} {
  variable timer

  if {[catch {killutimer ${timer}} error] != 0} {
    putlog "\[ngBot\] ${ns} :: Warning: Unable to kill announce timer \"${error}\""
  }
}

proc startTimer {} {
  variable quotat
  variable timer [utimer ${quotat(interval)} "[namespace current]::showquotat"]
}

proc TXT:ESPACE:DISPLAY { text length } {
  set text                      [string trim ${text}]
  set text_length               [string length ${text}];
  set espace_length             [expr (${length} - ${text_length})/2.0]
  set ESPACE_TMP                [split ${espace_length} .]
  set ESPACE_ENTIER             [lindex ${ESPACE_TMP} 0]
  set ESPACE_DECIMAL            [lindex ${ESPACE_TMP} 1]
  if { ${ESPACE_DECIMAL} == 0 } {
    set espace_one              [string repeat " " ${ESPACE_ENTIER}];
    set espace_two              [string repeat " " ${ESPACE_ENTIER}];
    return "${espace_one}${text}${espace_two}"
  } else {
    set espace_one              [string repeat " " ${ESPACE_ENTIER}];
    set espace_two              [string repeat " " [expr (${ESPACE_ENTIER}+1)]];
    return "${espace_one}${text}${espace_two}"
  }

}
proc showquotat {args} {
  variable np
  variable quotat
  variable ${np}::binary
  variable ${np}::location

  [namespace current]::startTimer

  if {[catch {exec ${binary(STATS)} -r ${location(GLCONF)} -u -w -x ${quotat(users_limit)} -s ${quotat(sect)}} output] != 0} {
    putlog "\[ngBot\] ${ns} :: Error: Problem executing stats-exec \"${output}\""
    return
  }

  set msg [list]
  foreach line [split ${output} "\n"] {
    regsub -all -- {(\s+)\s} ${line} " " line

    if {[regexp -- {^\[(\d+)\] (.*?) (.*?) (\d+) (\d+)\w+ (\S+)} ${line} -> pos username tagline files bytes speed]} {
      putnow "PRIVMSG ${chan} :${quotat(prefix)}"
      foreach chan [split ${quotat(chan)}] {
        putnow "PRIVMSG ${chan} :\[${pos}. ${username} \002${bytes}\002M /${for_pass}\]"
      }
    }
  }

  if {[llength ${msg}] == 0} {
    set msg "Empty..."
  }

  foreach chan [split ${quotat(chan)}] {
    puthelp "PRIVMSG ${chan} :${${quotat(prefix)}}[join ${msg} " "]"
  }
}
}
