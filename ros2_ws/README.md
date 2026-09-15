# Exoskeleton ROS 2 workspace

Workspace này chạy trên Raspberry Pi (khuyến nghị Ubuntu 24.04 + ROS 2 Jazzy).
Nó tách khỏi Flutter app: Pi là nơi duy nhất được phép quyết định và phát lệnh
tới motor controller.

## Kiến trúc kết nối

```
Flutter app -- BLE (lệnh cấp cao) --> Pi BLE bridge --> /exo/exercise/request
ESP32 buttons/OLED -- UART1/UART2 --> Pi UART bridge --> ROS2 safety gateway
Backend ---- HTTPS/MQTT (profile, plan, log) -------> Pi cloud sync
                                                     safety gate --> actuator adapter
```

App và ESP32 không gửi torque, PWM, tốc độ hoặc góc motor. BLE/UART chỉ mang các ý định mức cao
như `start`, `pause`, `stop`, và `set_assist_percent`; Pi kiểm tra trạng thái cảm
biến, profile đã được phê duyệt, công tắc E-stop, giới hạn cơ khí và watchdog trước
khi phát lệnh. Server không nằm trong đường điều khiển thời gian thực: mất Internet
không được làm thay đổi trạng thái an toàn.

BLE là lựa chọn tốt cho phiên điều khiển gần thiết bị vì hoạt động offline, độ trễ
thấp và quyền điều khiển dễ gắn với thiết bị đang pair. Dùng HTTPS/MQTT tới server
cho đăng nhập, kế hoạch điều trị đã ký/phiên bản hoá, telemetry, audit log và cập
nhật firmware. Không mở ROS graph trực tiếp cho điện thoại hay Internet.

## Triển khai code sang Raspberry Pi

Từ máy phát triển, chạy lệnh dưới đây. `rsync` sẽ hỏi mật khẩu SSH trong
terminal; không đặt mật khẩu vào script hoặc git:

```bash
./tools/deploy_to_pi.sh
```

Sau đó SSH vào Pi và khởi tạo container:

```bash
ssh robot@192.168.100.210
~/ros2_ws/scripts/start_ros2.sh
```

Nếu container đã tồn tại, script sẽ dùng lại `ros2-jazzy`; không chạy thêm
container thứ hai dùng cùng UART.

## Chạy gateway

## Raspberry Pi 4B: chạy bằng Docker Jazzy

Pi không có `ros2` trên host là bình thường trong cách cài này; ROS nằm trong
container `ros:jazzy-ros-base`. Code workspace được mount từ `~/ros2_ws` của Pi.

Trên Pi host, kiểm tra UART và Bluetooth:

```bash
ls -l /dev/serial1 /dev/ttyAMA* /dev/ttyS* 2>/dev/null
sudo systemctl enable --now bluetooth
bluetoothctl show
```

Khởi chạy container (lần đầu; các lần sau dùng `docker start -ai ros2-jazzy`):

```bash
docker run -it --name ros2-jazzy --network host --privileged \
  -v /dev:/dev -v /run/dbus:/run/dbus \
  -v ~/ros2_ws:/root/ros2_ws ros:jazzy-ros-base bash
```

Trong container:

```bash
apt-get update && apt-get install -y python3-serial python3-venv
source /opt/ros/jazzy/setup.bash
cd /root/ros2_ws
python3 -m venv --system-site-packages .venv
.venv/bin/pip install -r src/exo_gateway/requirements-ble.txt
colcon build --symlink-install
source install/setup.bash
scripts/run_gateway.sh
```

Trên Pi 4B, sau khi bật `enable_uart=1` và `dtoverlay=miniuart-bt`, UART trên
chân GPIO là `/dev/serial0` (thường trỏ tới `ttyAMA0`); `/dev/serial1` dành cho
Bluetooth. TX/RX nối chéo với RX2/TX2 của ESP32, chung GND. Nếu Pi dùng tên
thiết bị khác, đổi `device` trong
`src/exo_gateway/config/safety.yaml`. Không nối trực tiếp mức điện áp 5 V vào
ESP32; xác nhận pin UART và mức 3.3 V trên đúng board.

Chuẩn UART cố định: 115200 baud, 8 data bits, no parity, 1 stop bit (8N1),
Pi TX nối ESP32 RX2 GPIO16, Pi RX nối ESP32 TX2 GPIO17, và chung GND. Trên
ESP32 đây là HardwareSerial(2). Trên Pi, device /dev/serial0 là UART GPIO
sau overlay hiện tại; không dùng /dev/serial1 nếu nó đang dành cho Bluetooth.

ESP32 gửi định kỳ device_status gồm battery_voltage, battery_percent,
estop_active, command_watchdog_ok, fault_reason; Pi chuyển tiếp các trường
này qua BLE để Mobile đọc. Mạch đo pin phải là 56 kOhm phía pin và 10 kOhm
xuống GND, không đưa điện áp pin trực tiếp vào ESP32.

### Kiểm tra flow chọn bài và trạng thái

Điện thoại chọn bài theo chuỗi:

Mobile prepare_exercise -> BLE Pi -> /exo/exercise/prepare -> SafetyGateway
lưu session -> Mobile exercise_command(start) -> /exo/exercise/request ->
/exo/exercise/accepted -> UART Pi -> ESP32 UART2.

ESP32 xác nhận bằng exercise_status; UART bridge đưa lên
/exo/exercise/status; BLE bridge đưa tiếp cho Mobile. Khi bấm GPIO13/GPIO4,
ESP32 phát exercise_selected; Pi chuyển event này thành
exercise_status(selected) để Mobile nhận được.

Nếu estop_active=true hoặc session chưa prepare, SafetyGateway cố ý không phát
lệnh start xuống ESP32 và Mobile sẽ nhận not_ready/rejected. Đây là đường đi
đúng và hiện tại motor chưa được phép chạy.

### Đọc log ROS và Bluetooth

Mở terminal SSH thứ hai. Trên host Pi, log BLE của BlueZ:

```bash
sudo journalctl -u bluetooth -f
sudo btmon
bluetoothctl devices
bluetoothctl info <MAC-ESP32-PI-PEER>
```

BLE ở hệ thống này là điện thoại ↔ Pi; ESP32 không cần pair BLE. ESP32 giao
tiếp với Pi bằng UART có dây. Trong container, dùng:

```bash
~/ros2_ws/scripts/uart_log.sh
ros2 topic echo /exo/state
ros2 topic echo /exo/exercise/status
ros2 topic hz /exo/state
```

Log trực tiếp của `uart_bridge` có các dòng `Connected ESP32 UART`, `UART TX`
và `UART RX`. Nếu thấy `UART unavailable`, kiểm tra:

```bash
ls -l /dev/serial1 /dev/ttyAMA* /dev/ttyS* 2>/dev/null
sudo fuser -v /dev/serial0
```

Nếu chỉ muốn test ROS + UART khi Bluetooth chưa cấu hình xong:

```bash
ros2 launch exo_gateway safety_gateway.launch.py enable_ble:=false
```

Trong container, log node và xem dữ liệu:

```bash
source /opt/ros/jazzy/setup.bash
source /root/ros2_ws/install/setup.bash
ros2 node list
ros2 topic list
ros2 topic echo /exo/state
ros2 topic echo /exo/exercise/status
ros2 topic echo /exo/exercise/accepted
ros2 topic hz /exo/state
```

Kiểm tra UART mà không cần app:

```bash
ros2 topic pub --once /exo/exercise/request exo_interfaces/msg/ExerciseCommand \
  "{sequence: 1, session_id: test, exercise_code: raise_left_leg, action: 0, side: 1, repetitions: 1, assist_percent: 0.0}"
```

Mặc định `estop_active: true`, nên SafetyGateway sẽ từ chối mọi lệnh start và
ESP32 firmware mẫu cũng trả `not_ready`. Chỉ chuyển sang adapter E-stop thật sau
khi đã test bench, encoder, giới hạn dòng/nhiệt và watchdog độc lập.

```bash
source /opt/ros/jazzy/setup.bash
cd ros2_ws
rosdep install --from-paths src --ignore-src -r -y
python3 -m venv --system-site-packages .venv
.venv/bin/pip install -r src/exo_gateway/requirements-ble.txt
colcon build --symlink-install
source install/setup.bash
source .venv/bin/activate
export PYTHONPATH="$VIRTUAL_ENV/lib/python$(python -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")')/site-packages:$PYTHONPATH"
scripts/run_gateway.sh
```

Trước khi chạy BLE bridge trên Pi, cài BlueZ và thư viện GATT peripheral:

```bash
sudo apt install bluez python3-venv
sudo systemctl enable --now bluetooth
```

Thiết bị quảng bá tên `ExoLeg-1`. BLE service UUID là
`6e400101-b5a3-f393-e0a9-e50e24dcca9e` (GATT schema v2). Control characteristic
chỉ nhận JSON UTF-8 protocol v1 `prepare_exercise`; status characteristic là notify.
Chi tiết UUID, payload và các status có tại [BLE_PROTOCOL.md](BLE_PROTOCOL.md).
Sau khi production pairing/bonding được chốt, BlueZ phải whitelist bonded central trước
khi chạy bridge. Không dùng BLE pairing mặc định làm cơ chế uỷ quyền lâm sàng.

Trong terminal khác, gửi thử lệnh enable (mặc định bị chặn cho tới khi E-stop được
tích hợp bằng hardware adapter):

```bash
ros2 topic pub --once /exo/command/request exo_interfaces/msg/DeviceCommand \
  "{sequence: 1, mode: 1, enable: true, assist_percent: 20.0}"
```

`exo_gateway` hiện chỉ publish lệnh đã được kiểm tra tới `/exo/command/accepted`.
Thay publisher này bằng driver CAN/UART thực tế chỉ sau khi hoàn tất safety review,
test HIL và fail-safe độc lập ở motor controller.

### Dataset và luồng nút ESP32

Tám mã bài tập được dùng thống nhất ở database, Mobile, BLE, ROS2 và firmware:
`walk`, `raise_left_leg`, `raise_right_leg`, `sit_to_stand`, `kick_left_leg`,
`kick_right_leg`, `kick_left_knee`, `kick_right_knee`. GPIO13/GPIO4 phát
`exercise_selected` qua UART; GPIO2 phát yêu cầu start/stop. `SafetyGateway`
kiểm tra mã bài, phía trái/phải, số lần, assist và E-stop trước khi phát
`exercise_command` xuống ESP32. Chỉ cần bổ sung actuator adapter sau lớp này để
ánh xạ từng `exercise_code` vào profile encoder/giới hạn cơ khí/PWM.
