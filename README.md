perl -0777 -i.bak -pe 's/format = "\[\$symbol\$context\( \\\(\$namespace\\\)\)\]\(\$style\) "/format = "[$symbol$context( ($namespace))]($style) "/g' ~/.config/starship.toml
