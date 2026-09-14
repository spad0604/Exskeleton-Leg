#!/usr/bin/env bash
# ROS setup scripts reference optional variables, so load them before enabling
# nounset/strict mode.
source /opt/ros/jazzy/setup.bash
cd /root/ros2_ws
source install/setup.bash
set -euo pipefail

# ROS 2 executables use the system interpreter from the base image. Expose the
# workspace virtualenv packages to that interpreter without replacing ROS 2.
if [[ -d .venv/lib ]]; then
  VENV_SITE_PACKAGES="$(find .venv/lib -maxdepth 3 -type d -name site-packages -print -quit)"
  if [[ -n "${VENV_SITE_PACKAGES}" ]]; then
    export PYTHONPATH="${VENV_SITE_PACKAGES}:${PYTHONPATH:-}"
  fi
fi

exec ros2 launch exo_gateway safety_gateway.launch.py
