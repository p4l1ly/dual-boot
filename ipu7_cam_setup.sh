#!/usr/bin/env bash

# ---------- basics ----------
if ! command -v pacman >/dev/null; then
  echo "This script is for Arch/derivatives (uses pacman)."; exit 1
fi

# Pick the right headers package for the running kernel
KREL="$(uname -r)"
HEADERPKG=linux-headers
case "$KREL" in
  *-zen*) HEADERPKG=linux-zen-headers ;;
  *-lts*) HEADERPKG=linux-lts-headers ;;
esac

echo "== Installing build/runtime prerequisites =="
sudo pacman -S --needed \
  git base-devel autoconf automake libtool pkgconf cmake \
  gstreamer gst-plugins-base gst-plugins-bad libdrm glib2 \
  v4l-utils i2c-tools dkms "${HEADERPKG}"

# Work directory
WORKDIR="${WORKDIR:-$HOME/ipu7-work}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ---------- 1) Deploy ipu7 firmware + libs + headers + .pc ----------
if [ ! -d ipu7-camera-bins ]; then
  git clone https://github.com/intel/ipu7-camera-bins.git
fi
cd ipu7-camera-bins

echo "== Installing IPU7 firmware, libraries, headers, pkgconfig =="
sudo install -d /lib/firmware/intel/ipu /usr/lib/pkgconfig /usr/include
sudo cp -v lib/firmware/intel/ipu/*.bin /lib/firmware/intel/ipu/
sudo cp -vP lib/lib* /usr/lib/
sudo cp -vr lib/pkgconfig/* /usr/lib/pkgconfig/
sudo cp -vr include/* /usr/include/

# Ensure devel symlinks exist (ld resolves -lcamhal)
[ -e /usr/lib/libcamhal.so ] || sudo ln -s /usr/lib/libcamhal.so.0 /usr/lib/libcamhal.so
# (Optional) some builds want a non-versioned ia_view link:
if [ -e /usr/lib/libia_view-ipu7x.so.0 ] && [ ! -e /usr/lib/libia_view-ipu7x.so ]; then
  sudo ln -s /usr/lib/libia_view-ipu7x.so.0 /usr/lib/libia_view-ipu7x.so
fi
sudo ldconfig
cd ..

# ---------- 2) Build & install IPU7 Camera HAL ----------
if [ ! -d ipu7-camera-hal ]; then
  git clone https://github.com/intel/ipu7-camera-hal.git
fi
cd ipu7-camera-hal
rm -rf build && mkdir build && cd build
echo "== Building IPU7 Camera HAL =="
cmake -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_CAMHAL_ADAPTOR=ON -DBUILD_CAMHAL_PLUGIN=ON \
  -DIPU_VERSIONS="ipu7x;ipu75xa" \
  -DUSE_STATIC_GRAPH=ON -DUSE_STATIC_GRAPH_AUTOGEN=ON ..
make -j"$(nproc)"
sudo make install
cd ../..

# ---------- 3) Build & install icamerasrc (slim_api + DRM formats) ----------
if [ ! -d icamerasrc ]; then
  git clone -b icamerasrc_slim_api https://github.com/intel/icamerasrc.git
fi
cd icamerasrc
echo "== Generating configure scripts =="
./autogen.sh
if ! ./configure --help | grep -q -- '--enable-gstdrmformat'; then
  echo "ERROR: Not on icamerasrc_slim_api or autogen failed."; exit 1
fi
echo "== Configuring icamerasrc with DRM format support =="
PKG_CONFIG_PATH=/usr/lib/pkgconfig:$PKG_CONFIG_PATH \
CHROME_SLIM_CAMHAL=ON \
./configure --prefix=/usr --enable-gstdrmformat=yes
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd ..

# ---------- 4) Build & install Vision (intel_cvs) ----------
if [ ! -d vision-drivers ]; then
  git clone https://github.com/intel/vision-drivers.git
fi
cd vision-drivers
echo "== Building intel_cvs (Vision driver) =="
# Try simple make; if the repo expects in-tree build, fall back to kernel M= build.
make -j"$(nproc)" || make -C /lib/modules/"$(uname -r)"/build M="$PWD" modules
CVS_KO="$(find . -maxdepth 2 -name intel_cvs.ko -print -quit || true)"
if [ -z "${CVS_KO}" ]; then echo "ERROR: intel_cvs.ko not found"; exit 1; fi
sudo install -D -m 644 "$CVS_KO" /usr/lib/modules/"$(uname -r)"/extra/intel_cvs.ko
sudo depmod -a
cd ..

# ---------- 5) Build & install platform glue (intel_skl_int3472) ----------
if [ ! -d ipu6-drivers ]; then
  git clone https://github.com/intel/ipu6-drivers.git
fi
cd ipu6-drivers
echo "== Building intel_skl_int3472 (platform glue) =="
make -C /lib/modules/"$(uname -r)"/build M="$PWD"/drivers/platform/x86 modules
sudo install -D -m 644 drivers/platform/x86/intel_skl_int3472.ko \
  /usr/lib/modules/"$(uname -r)"/extra/intel_skl_int3472.ko
sudo depmod -a
cd ..

# ---------- 6) Load bridges/glue/sensor in the right order ----------
echo "== Loading bridges/glue/sensor modules =="
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe usb-ljca || true
sudo modprobe gpio-ljca || true
sudo modprobe i2c-ljca || true
sudo modprobe intel_cvs || true
sudo modprobe intel_skl_int3472 || true
sudo modprobe ov02c10 || true

# Re-enumerate IPU7 after bridges are up
sudo modprobe -r intel_ipu7_isys intel_ipu7_psys intel_ipu7 2>/dev/null || true
sudo modprobe intel_ipu7

# ---------- 7) Persist module load on boot ----------
echo "== Enabling module autoload on boot =="
sudo bash -c 'cat >/etc/modules-load.d/ipu7-cam.conf <<EOF
usb-ljca
gpio-ljca
i2c-ljca
intel_cvs
intel_skl_int3472
EOF'

shopt -s extglob

# -------------------- 可调参数 --------------------
DEVICE_NR="${DEVICE_NR:-42}"              # v4l2loopback 设备号
LABEL="${LABEL:-LibcameraCam}"            # 虚拟相机显示名
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
FPS="${FPS:-30}"
SRC_DIR="${SRC_DIR:-$HOME/src}"           # 源码下载目录
BUILD_LIBCAMERA="${BUILD_LIBCAMERA:-auto}"# auto/always/skip
# --------------------------------------------------

cecho(){ printf '\033[1;32m== %s\033[0m\n' "$*"; }
wecho(){ printf '\033[1;33m!! %s\033[0m\n' "$*"; }
eecho(){ printf '\033[1;31m** %s\033[0m\n' "$*"; }

require_cmd(){ command -v "$1" >/dev/null 2>&1 || { eecho "缺少命令: $1"; exit 1; }; }

# 0) 基础依赖
cecho "安装基础依赖（pacman）"
sudo pacman -S --needed --noconfirm \
  base-devel git pkgconf meson ninja \
  gstreamer gst-plugins-base gst-plugins-good \
  libdrm libjpeg-turbo libtiff libevent \
  v4l-utils inotify-tools lsof

# 1) 构建并安装 libcamera(HEAD) + GStreamer 插件（/usr/local）
need_libcamera_build() {
  case "$BUILD_LIBCAMERA" in
    always) return 0 ;;
    skip)   return 1 ;;
    auto)
      # 没有 libcamerasrc 或 cam 不可用则构建
      if ! gst-inspect-1.0 libcamerasrc >/dev/null 2>&1; then return 0; fi
      if ! command -v cam >/dev/null 2>&1 && ! command -v qcam >/dev/null 2>&1; then return 0; fi
      return 1
      ;;
  esac
}

if need_libcamera_build; then
  cecho "构建并安装 libcamera(HEAD) 到 /usr/local（含 GStreamer 插件）"
  mkdir -p "$SRC_DIR" && cd "$SRC_DIR"
  rm -rf libcamera
  git clone --depth=1 https://git.libcamera.org/libcamera/libcamera.git
  cd libcamera
  meson setup build \
    -Dprefix=/usr/local \
    -Dpipelines=simple \
    -Dgstreamer=enabled \
    -Dcam=enabled -Dqcam=enabled \
    -Dtest=false -Ddocumentation=disabled
  ninja -C build
  sudo meson install -C build
  sudo ldconfig
else
  wecho "跳过 libcamera 构建（BUILD_LIBCAMERA=${BUILD_LIBCAMERA})"
fi

# 2) 安装并加载 v4l2loopback，固定 /dev/video$DEVICE_NR
cecho "安装并加载 v4l2loopback（/dev/video${DEVICE_NR}，标签 ${LABEL}）"
if ! pacman -Qi v4l2loopback-dkms >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm v4l2loopback-dkms || true
  fi
  sudo pacman -S --needed --noconfirm v4l2loopback-dkms || true
fi

# 持久化加载
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf >/dev/null
sudo tee /etc/modprobe.d/v4l2loopback.conf >/dev/null <<CONF
options v4l2loopback devices=1 video_nr=${DEVICE_NR} card_label=${LABEL} exclusive_caps=1
CONF

# 立即生效
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe v4l2loopback
sleep 0.4

if [[ ! -e "/dev/video${DEVICE_NR}" ]]; then
  eecho "/dev/video${DEVICE_NR} 未出现，请检查内核头/DKMS/日志"
  exit 1
fi

v4l2-ctl -D -d "/dev/video${DEVICE_NR}" || true
v4l2-ctl --list-formats-out -d "/dev/video${DEVICE_NR}" || true

# 3) 可选尝试加载平台桥接（失败忽略，仅 best-effort）
cecho "可选：加载平台桥接（失败将忽略）"
for m in usb-ljca gpio-ljca i2c-ljca spi-ljca; do
  sudo modprobe "$m" 2>/dev/null || true
done
# Intel USBIO（若你已安装 DKMS）
for m in usbio usbio-bridge i2c-usbio gpio-usbio usbio-gpio; do
  sudo modprobe "$m" 2>/dev/null || true
done
# 传感器（如 OVTI02C1=ov02c10）
sudo modprobe ov02c10 2>/dev/null || true

# 4) 部署智能桥接脚本（黑屏待机/按读者切换）
cecho "部署智能桥接脚本到 ~/.local/bin"
mkdir -p "$HOME/.local/bin"

RUN_SH="$HOME/.local/bin/libcamera-bridge-run.sh"
IDLE_SH="$HOME/.local/bin/libcamera-bridge-idle.sh"
SMART_SH="$HOME/.local/bin/libcamera-bridge-smart.sh"

cat > "$RUN_SH" <<SH
#!/usr/bin/env bash
set -euo pipefail
DEV="\${1:-/dev/video${DEVICE_NR}}"
export GST_PLUGIN_PATH="/usr/local/lib/gstreamer-1.0\${GST_PLUGIN_PATH+:\$GST_PLUGIN_PATH}"
export LIBCAMERA_PIPELINE="simple"
exec gst-launch-1.0 -q \\
  libcamerasrc name=src \\
  ! video/x-raw,format=RGBA,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1 \\
  ! videoconvert ! video/x-raw,format=YUY2 \\
  ! queue leaky=downstream max-size-buffers=4 \\
  ! v4l2sink device="\$DEV" sync=false
SH

cat > "$IDLE_SH" <<SH
#!/usr/bin/env bash
set -euo pipefail
DEV="\${1:-/dev/video${DEVICE_NR}}"
exec gst-launch-1.0 -q \\
  videotestsrc pattern=black is-live=true \\
  ! video/x-raw,format=YUY2,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1 \\
  ! v4l2sink device="\$DEV" sync=false
SH

cat > "$SMART_SH" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
DEV="${1:-/dev/video42}"
IDLE_SECS="${IDLE_SECS:-3}"

BLACK_PID=""
CAM_PID=""

start_black() {
  if [[ -n "${BLACK_PID}" ]] && kill -0 "${BLACK_PID}" 2>/dev/null; then return; fi
  "$HOME/.local/bin/libcamera-bridge-idle.sh" "$DEV" &
  BLACK_PID=$!
  echo "[smart] idle black started pid=$BLACK_PID"
}

stop_black() {
  if [[ -n "${BLACK_PID}" ]] && kill -0 "${BLACK_PID}" 2>/dev/null; then
    kill -INT "$BLACK_PID" 2>/dev/null || true
    wait "$BLACK_PID" 2>/dev/null || true
    echo "[smart] idle black stopped"
  fi
  BLACK_PID=""
}

start_cam() {
  if [[ -n "${CAM_PID}" ]] && kill -0 "${CAM_PID}" 2>/dev/null; then return; fi
  stop_black
  "$HOME/.local/bin/libcamera-bridge-run.sh" "$DEV" &
  CAM_PID=$!
  echo "[smart] camera started pid=$CAM_PID"
}

stop_cam() {
  if [[ -n "${CAM_PID}" ]] && kill -0 "${CAM_PID}" 2>/dev/null; then
    kill -INT "$CAM_PID" 2>/dev/null || true
    wait "$CAM_PID" 2>/dev/null || true
    echo "[smart] camera stopped"
  fi
  CAM_PID=""
}

cleanup(){ stop_cam; stop_black; exit 0; }
trap cleanup INT TERM

have_readers() {
  local pids readers
  pids=$(lsof -t "$DEV" 2>/dev/null | sort -u || true)
  readers=0
  for p in $pids; do
    for fd in /proc/$p/fd/*; do
      [[ -e "$fd" ]] || continue
      local link; link=$(readlink "$fd" 2>/dev/null || true)
      [[ "$link" == "$DEV" ]] || continue
      local fi; fi="/proc/$p/fdinfo/$(basename "$fd")"
      [[ -r "$fi" ]] || continue
      local flags_hex; flags_hex=$(awk '/^flags:/{print $2}' "$fi")
      [[ -n "$flags_hex" ]] || continue
      local flags=$((flags_hex))
      if (( (flags & 3) != 1 )); then readers=1; break; fi
    done
    (( readers )) && break
  done
  (( readers ))
}

until [[ -e "$DEV" ]]; do echo "[smart] waiting for $DEV ..."; sleep 1; done
start_black

inotifywait -m -e open -e close -e move_self -e delete_self "$DEV" |
while read -r _ EVENT _; do
  case "$EVENT" in
    *OPEN* )
      if have_readers; then start_cam; fi
      ;;
    *CLOSE* )
      sleep "$IDLE_SECS"
      if ! have_readers; then
        stop_cam
        start_black
      fi
      ;;
    *MOVE_SELF*|*DELETE_SELF* )
      cleanup
      exec "$0" "$DEV"
      ;;
  esac
done
SH

chmod +x "$RUN_SH" "$IDLE_SH" "$SMART_SH"

# 5) 清理旧服务 & 创建/启用新的 systemd --user 服务
cecho "清理旧的服务并创建新服务（libcamera-bridge-smart）"
systemctl --user disable --now libcamera-bridge-onopen.service 2>/dev/null || true
systemctl --user disable --now libcamera-bridge-autods.service 2>/dev/null || true
systemctl --user disable --now libcamera-bridge.service 2>/dev/null || true
systemctl --user disable --now libcamera-bridge-prewarm.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user"/libcamera-bridge-{onopen,autods,prewarm,service}.service 2>/dev/null || true

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/libcamera-bridge-smart.service" <<UNIT
[Unit]
Description=Smart libcamera -> v4l2loopback: idle black, switch to camera on readers
After=default.target
ConditionPathExists=/dev/video${DEVICE_NR}

[Service]
Type=simple
ExecStart=%h/.local/bin/libcamera-bridge-smart.sh /dev/video${DEVICE_NR}
Restart=always
RestartSec=1

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now libcamera-bridge-smart.service
systemctl --user status libcamera-bridge-smart.service --no-pager -l || true

# 6) 将当前用户加入 video 组（如未加入）
if ! id -nG "$USER" | tr " " "\n" | grep -qx video; then
  wecho "将 $USER 加入 video 组（重新登录后生效）"
  sudo gpasswd -a "$USER" video || true
fi

# 7) 最后提示
cecho "完成！现在应用里选择 \"${LABEL}\"（/dev/video${DEVICE_NR}）即可使用："
echo " - 空闲：黑屏待机（不点灯）"
echo " - 打开：自动切换到真实摄像头（点灯）"
echo " - 关闭：数秒后自动返回黑屏（灭灯）"
echo
echo "常用："
echo "  journalctl --user -fu libcamera-bridge-smart.service   # 实时看启停日志"
echo "  v4l2-ctl --list-devices                                # 查看虚拟相机是否可见"


