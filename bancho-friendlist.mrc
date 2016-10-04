; == PROLOGUE ==
; This stems from http://hawkee.com/snippet/9574/, which I used as a starting
;     point.
;
; == USAGE ==
; * Tweak %timeout_ms variable to your needs; if you have a friendlist of N users,
;     a full cycle of status update takes N * %timeout_ms / 1000 seconds. For example,
;     for timeout of 200ms and 50 friends you'll receive status updates with a 10s delay.
; * Press F9, or change the hotkey right away (the first alias).
; * Load nicknames from a file (each nickname on a new line) or type in manually
;     into Notify tab of Address book window.
; * Enjoy?
;
; == SIDE EFFECTS / LIMITATIONS ==
; * While friendlist is on, all WHOIS output for friends is suppressed. I made it so that
;     my Status tab wasn't always clogged with trash, because, due to the fact that
;     we don't have ISON on Bancho, the script has to frequently send WHOIS queries
;     for each nickname to figure whether it's online or not. As a bonus, you can borrow
;     osuFriendlist.extractName and, with a little work, get yourself a WHOIS output
;     that properly works with nicknames that contain spaces. No more "White using Fox"
;     for white foxes of all sorts and suchs!
;
; == THANKS ==
; * Kyubey for throwing me http://hawkee.com/snippet/9574, which I couldn't leave alone
; * The contributors of Wikibooks and WikiChip, and the author/s of www.mirc.com/help/mirc.pdf
;
; -- TicClick


alias F9 {
  osuFriendlist.launch
}

alias osuFriendlist.launch {
  dialog $iif($dialog(osuFriendlist.System),-v,-m osuFriendlist.System) osuFriendlist.System
}

Menu Menubar,Nicklist,Channel {
  Tools
  .osuFriendlist: osuFriendlist.launch
}

Dialog osuFriendlist.System {
  Title "Friends"
  Size -1 -1 120 170
  Option dbu

  box "Online", 444, 2 2 80 72
  list 1, 5 10 74 72, hsbar vsbar
  box "Offline", 445, 2 82 80 72
  list 2, 5 90 74 72, hsbar vsbar

  button "Edit", 5, 84 02 30 10, flat

  menu "File", 6
  item "Load names from file", 11, 6
}

Dialog osuFriendlist.Warning {
  Title "Warning"
  Size -1 -1 150 50

  text "Unable to open file.", 1, 30 18 100 26
}

on *:DIALOG:osuFriendlist.System:*:*: {
  if ($devent == init) {
    hmake osuFriendlist.online $notify(0)
    hmake osuFriendlist.offline $notify(0)

    var %timeout_ms = 100

    osuFriendlist.updateNames
    .timerosuFriendlist.whoisNext -m 0 %timeout_ms osuFriendlist.whoisNext
  }

  if ($devent == close) {
    .timerosuFriendlist.whoisNext off
    hfree osuFriendlist.offline
    hfree osuFriendlist.online
    unset %osuFriendlist.pollIdx
  }

  if ($devent == dclick) {
    if ($did == 1 || $did == 2) {
      scid $activecid .query $gettok($did(1).seltext,1,32)
    }
  }

  if ($devent == sclick) {
    if ($did == 5) {
      .abook -n
    }
  }

  if ($devent == menu) {
    if ($did == 11) {
      $$?="Path to a file with nicknames (each on a new line):"
      fopen names $!
      if ($fopen(names).err) {
        dialog -m osuFriendlist.Warning osuFriendlist.Warning
        fclose names
        return
      }
      while (!$fopen(names).eof) {
        var %name = $replace($fread(names), $chr(32), _)
        notify %name
      }
      fclose names
      osuFriendlist.updateNames
    }
  }
}

alias osuFriendlist.updateNames {
  .timerosuFriendlist.whoisNext -p
  set %osuFriendlist.pollIdx 1
  var %idx 1
  while (%idx <= $notify(0)) {
    if (!$osuFriendlist.isFriend($notify(%idx))) {
      hadd osuFriendlist.offline $notify(%idx) %idx
      did -az osuFriendlist.system 2 $notify(%idx)
    }
    inc %idx
  }
  .timerosuFriendlist.whoisNext -r
}

alias osuFriendlist.posInListDialog {
  var %idx = 1
  while (%idx <= $did(osuFriendlist.system, $$1).lines) {
    if ($did(osuFriendlist.system, $$1, %idx).text == $$2) {
      return %idx
    }
    inc %idx
  }
  return $null
}

alias osuFriendlist.setStatus {
  var %to_id = $iif($2 == online, 1, 2)
  var %from_id = $iif($2 == online, 2, 1)
  var %to_table = osuFriendlist. [ $+ [ $2 ] ]
  var %from_table = osuFriendlist. $+ $iif($2 == online, offline, online)

  if ($hget(%to_table, $1) != $null) {
    return
  }

  var %idx = $osuFriendlist.posInListDialog(%from_id, $1)
  did -d osuFriendlist.system %from_id %idx
  did -az osuFriendlist.system %to_id $1
  hadd %to_table $1 1
  hdel %from_table $1
}

alias osuFriendlist.whoisNext {
  whois $notify(%osuFriendlist.pollIdx)
  %osuFriendlist.pollIdx = $calc(%osuFriendlist.pollIdx % $notify(0) + 1)
}

alias osuFriendlist.extractName {
  if ($prop == 311 || $prop == 319 || $prop == 312) {
    var %stop_marker = $iif($prop == 311, https://, $iif($prop == 319, $chr(35), $iif($prop == 312, cho.ppy.sh)))
    var %exact_marker = $matchtok($1, %stop_marker, 1, 32)
    var %idx = $findtok($1, %exact_marker, 1, 32)
    var %name = $gettok($1, 1 - $calc(%idx - 1), 32)
    return $replace(%name, $chr(32), _)
  }

  if($prop == 318 || $prop == 401) {
    var %to_remove = $iif($prop == 318, End of /WHOIS list., No such nick/channel)
    var %name = $remove($1, %to_remove)
    return $replace(%name, $chr(32), _)
  }
}

alias osuFriendlist.isFriend {
  var %name_in_friendlist = $iif(($hget(osuFriendlist.offline, $1) || $hget(osuFriendlist.online, $1)), $true, $false)
  var %is_friendlist_on = $iif($dialog(osuFriendlist.System), $true, $false)
  return $iif(%name_in_friendlist && %is_friendlist_on, $true, $false)
}

raw 311:*:{
  ; WHOIS beginning
  var %name = $osuFriendlist.extractName($2-).311
  if ($osuFriendlist.isFriend(%name)) {
    haltdef
    osuFriendlist.setStatus %name online
  }
}

raw 319:*:{
  ;WHOIS channels
  var %name = $osuFriendlist.extractName($2-).319
  if ($osuFriendlist.isFriend(%name)) {
    haltdef
  }
}

raw 312:*:{
  ;WHOIS host
  var %name = $osuFriendlist.extractName($2-).312
  if ($osuFriendlist.isFriend(%name)) {
    haltdef
  }
}

raw 318:*:{
  ;WHOIS end
  var %name = $osuFriendlist.extractName($2-).318
  if ($osuFriendlist.isFriend(%name)) {
    haltdef
  }
}

raw 401:*:{
  ;name lookup fail
  var %name = $osuFriendlist.extractName($2-).401
  if ($osuFriendlist.isFriend(%name)) {
    haltdef
    osuFriendlist.setStatus %name offline
  }
}
