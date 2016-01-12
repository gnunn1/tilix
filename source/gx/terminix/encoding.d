/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.encoding;

import gx.i18n.l10n;

/**
 * Hashmap of encodings
 */
string[string] lookupEncoding;

/**
 * Array of available encodings
 */
string[2][] encodings = [
       ["ISO-8859-1",	_("Western")], 
       ["ISO-8859-2",	_("Central European")], 
       ["ISO-8859-3",	_("South European")], 
       ["ISO-8859-4",	_("Baltic")], 
       ["ISO-8859-5",	_("Cyrillic")], 
       ["ISO-8859-6",	_("Arabic")], 
       ["ISO-8859-7",	_("Greek")], 
       ["ISO-8859-8",	_("Hebrew Visual")], 
       ["ISO-8859-8-I",	_("Hebrew")], 
       ["ISO-8859-9",	_("Turkish")], 
       ["ISO-8859-10",	_("Nordic")], 
       ["ISO-8859-13",	_("Baltic")], 
       ["ISO-8859-14",	_("Celtic")], 
       ["ISO-8859-15",	_("Western")], 
       ["ISO-8859-16",	_("Romanian")], 
       ["UTF-8",        _("Unicode")], 
       ["ARMSCII-8",    _("Armenian")], 
       ["BIG5",	        _("Chinese Traditional")], 
       ["BIG5-HKSCS",	_("Chinese Traditional")], 
       ["CP866",	    _("Cyrillic/Russian")], 
       ["EUC-JP",	    _("Japanese")], 
       ["EUC-KR",	    _("Korean")], 
       ["EUC-TW",	    _("Chinese Traditional")], 
       ["GB18030",	    _("Chinese Simplified")], 
       ["GB2312",	    _("Chinese Simplified")], 
       ["GBK",	        _("Chinese Simplified")], 
       ["GEORGIAN-PS",	_("Georgian")], 
       ["IBM850",	    _("Western")], 
       ["IBM852",	    _("Central European")], 
       ["IBM855",	    _("Cyrillic")], 
       ["IBM857",	    _("Turkish")], 
       ["IBM862",	    _("Hebrew")], 
       ["IBM864",	    _("Arabic")], 
       ["ISO-2022-JP",	_("Japanese")], 
       ["ISO-2022-KR",	_("Korean")], 
       ["ISO-IR-111",	_("Cyrillic")], 
       ["KOI8-R",	    _("Cyrillic")], 
       ["KOI8-U",	    _("Cyrillic/Ukrainian")], 
       ["MAC_ARABIC",	_("Arabic")], 
       ["MAC_CE",	    _("Central European")], 
       ["MAC_CROATIAN",	_("Croatian")], 
       ["MAC-CYRILLIC",	_("Cyrillic")], 
       ["MAC_DEVANAGARI",_("Hindi")], 
       ["MAC_FARSI",	    _("Persian")], 
       ["MAC_GREEK",	    _("Greek")], 
       ["MAC_GUJARATI",	_("Gujarati")], 
       ["MAC_GURMUKHI",	_("Gurmukhi")], 
       ["MAC_HEBREW",	_("Hebrew")], 
       ["MAC_ICELANDIC",	_("Icelandic")], 
       ["MAC_ROMAN",	    _("Western")], 
       ["MAC_ROMANIAN",	_("Romanian")], 
       ["MAC_TURKISH",	_("Turkish")], 
       ["MAC_UKRAINIAN",	_("Cyrillic/Ukrainian")], 
       ["SHIFT_JIS",	    _("Japanese")], 
       ["TCVN",	        _("Vietnamese")], 
       ["TIS-620",	    _("Thai")], 
       ["UHC",	        _("Korean")], 
       ["VISCII",	    _("Vietnamese")], 
       ["WINDOWS-1250",	_("Central European")], 
       ["WINDOWS-1251",	_("Cyrillic")], 
       ["WINDOWS-1252",	_("Western")], 
       ["WINDOWS-1253",	_("Greek")], 
       ["WINDOWS-1254",	_("Turkish")], 
       ["WINDOWS-1255",	_("Hebrew")], 
       ["WINDOWS-1256",	_("Arabic")], 
       ["WINDOWS-1257",	_("Baltic")], 
       ["WINDOWS-1258",	_("Vietnamese")]  
    ];

static this() {
    foreach(encoding; encodings) {
        lookupEncoding[encoding[0]] = encoding[1];
    }
}