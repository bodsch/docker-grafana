

insert_plugins() {

  local plugins="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel"

  for p in ${plugins}
  do
    /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins"  plugins install ${p}
  done
}


update_plugins() {

  echo -n " [i] update plugins"

  /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins upgrade-all 1> /dev/null

  echo "  done"
}

