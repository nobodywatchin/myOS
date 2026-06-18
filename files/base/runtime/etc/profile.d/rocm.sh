#!/bin/sh
if [ -d /opt/rocm/bin ]; then
  case ":${PATH:-}:" in
    *:/opt/rocm/bin:*) ;;
    *) PATH="/opt/rocm/bin${PATH:+:${PATH}}" ;;
  esac
fi
export PATH
