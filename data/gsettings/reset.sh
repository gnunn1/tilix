# Resets Tilix settings to default for testing purposes
gsettings list-schemas | grep Tilix | xargs -n 1 gsettings reset-recursively
dconf list /com/gexperts/Tilix/profiles/ | xargs -I {} dconf reset -f "/com/gexperts/Tilix/profiles/"{}
