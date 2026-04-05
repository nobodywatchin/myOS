#!/bin/sh
if [ -d /usr/local/cuda/bin ]; then
  case ":${PATH:-}:" in
    *:/usr/local/cuda/bin:*) ;;
    *) PATH="/usr/local/cuda/bin${PATH:+:${PATH}}" ;;
  esac
  CUDA_HOME=/usr/local/cuda
  CUDA_PATH=/usr/local/cuda
  export CUDA_HOME CUDA_PATH
fi
export PATH
