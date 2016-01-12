# Resets Terminix settings to default for testing purposes
gsettings list-schemas | grep Terminix | xargs -n 1 gsettings reset-recursively
dconf list /com/gexperts/Terminix/profiles/ | xargs -I {} dconf reset -f "/com/gexperts/Terminx/profiles/"{}
