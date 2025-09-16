# Default Flatpak CLI to --user in interactive shells, unless a scope is specified.
case $- in
  *i*)
    flatpak() {
      case "$1" in
        install|remove|uninstall|update|bundle|repair)
          has_scope=""
          for arg in "$@"; do
            case "$arg" in
              --user|--system) has_scope=1; break ;;
            esac
          done
          # Let admins explicitly choose --system; otherwise default to --user
          if [ -z "$has_scope" ]; then
            set -- --user "$@"
          fi
          ;;
      esac
      command flatpak "$@"
    }
  ;;
esac
