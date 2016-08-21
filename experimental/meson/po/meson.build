
langs = [
    'bg',
    'de',
    'el',
    'en',
    'es',
    'fr',
    'he',
    'id',
    'it',
    'ko',
    'lt',
    'pl',
    'pt_BR',
    'ru',
    'sv',
    'tr',
    'zh_CN',
    'zh_TW'
]

# really hacky way to generate the LINGUAS file.
# this is done mainly to not break the other build systems,
# actually the LINGUAS file and 'langs' list above should be maintained by hand.
linguas_cmd = run_command('bash', '-c', 'find' + ' ' + source_root + '/po' + ' ' + '-name "*\.po" -printf "%f\\n" | sed "s/\.po//g" | sort > ' + source_root + '/po/LINGUAS')
if linguas_cmd.returncode() != 0
    error('Could not generate LINGUAS file!\n' + linguas_cmd.stdout() + '\n' + linguas_cmd.stderr())
endif

i18n.gettext('terminix', languages: langs)
