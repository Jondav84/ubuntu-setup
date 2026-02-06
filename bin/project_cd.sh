#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  unityos)   cd ~/Projects/UnityOS ;;
  bob)       cd ~/Projects/Robotics_projects/BoB ;;
  secureai)  cd ~/Projects/AI_projects/Secure_Local_AI ;;
  bthub)     cd ~/Projects/Robotics_projects/Bluetooth_Hub ;;
  fullstack) cd ~/Projects/Fullstack_projects/Learning ;;
  *)
    echo "Usage: $0 {unityos|bob|secureai|bthub|fullstack}"
    exit 1
    ;;
esac

pwd
