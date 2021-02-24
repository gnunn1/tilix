install_man('tilix.1')

po4a = find_program('po4a-translate', required: false)

if po4a.found()

    locales = [ 'ca', 'cs', 'de', 'en_GB', 'es', 'fr', 'hr',
                'it', 'nb_NO', 'nl', 'oc', 'pl', 'pt_BR', 'pt',
                'pt_PT', 'ro', 'ru', 'sr', 'tr', 'uk', 'zh_Hant' ]

    foreach locale : locales
        custom_target('man_' + locale,
            output: locale,
            input: [ 'tilix.1', 'po/' + locale + '.man.po' ],
            command: [ po4a, '--keep', '0',
                             '--format', 'man',
                             '--master', '@INPUT0@',
                             '--po', '@INPUT1@',
                             '--localized', '@OUTPUT@/man1/tilix.1'],
            install: true,
            install_dir: get_option('mandir')
        )
    endforeach

endif
