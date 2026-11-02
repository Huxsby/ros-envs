#!/bin/bash
# ROS 2 Jazzy smoke test: Python libraries, a SMACH machine, and headless Gazebo Harmonic with a differential robot
# and a laser facing a wall, connected to ROS through ros_gz_bridge. Checks that the laser sees the wall and that
# cmd_vel moves the robot, and measures the real time factor. Depends on no project.
# Usage: bash smoke-test.sh   (~30-60 s; can run next to another simulation: it uses its own domain)
source /opt/ros/jazzy/setup.bash
# Own ROS 2 domain and Gazebo partition, so as not to mix with an open simulation (what master ports did in ROS 1).
# Fixed and arbitrary values.
export ROS_DOMAIN_ID=73 GZ_PARTITION=smoke_test ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST GZ_IP=127.0.0.1
DIR=$(mktemp -d)
LOG=$DIR/gz.log
FAILURES=0
ok()   { echo "  OK    $*"; }
fail() { echo "  FAIL  $*"; FAILURES=$((FAILURES + 1)); }

echo "== Machine"
bash "$(dirname "$0")/../machine.sh" | sed 's/^/  INFO  /'

echo "== Python libraries"
python3 - <<'PY' && ok "rclpy, smach, smach_ros, yasmin, tf_transformations, cv_bridge, cv2, numpy, pandas, matplotlib" || fail "libraries"
import rclpy, smach, smach_ros, yasmin, tf_transformations, cv_bridge, cv2, numpy, pandas, matplotlib
PY

echo "== SMACH"
python3 - <<'PY' && ok "two-state machine (ONE -> TWO -> done)" || fail "SMACH"
import smach

class Step(smach.State):
    def __init__(self):
        smach.State.__init__(self, outcomes=['next'])

    def execute(self, userdata):
        return 'next'

sm = smach.StateMachine(outcomes=['done'])
with sm:
    smach.StateMachine.add('ONE', Step(), transitions={'next': 'TWO'})
    smach.StateMachine.add('TWO', Step(), transitions={'next': 'done'})
assert sm.execute() == 'done'
PY

# world: ground, wall 3 m away (front face at x = 2.9) and a differential robot with a 0.34 m track and a laser of
# 180 samples over 180 degrees. The laser is gpu_lidar: on Harmonic it renders with ogre2 (on a GPU or llvmpipe),
# so this test also checks rendering.
cat >"$DIR/smoke.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.9">
  <world name="smoke">
    <physics name="1ms" type="ignored"><max_step_size>0.001</max_step_size><real_time_factor>1.0</real_time_factor></physics>
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
    <plugin filename="gz-sim-sensors-system" name="gz::sim::systems::Sensors"><render_engine>ogre2</render_engine></plugin>
    <model name="ground">
      <static>true</static>
      <link name="ground">
        <collision name="c"><geometry><plane><normal>0 0 1</normal><size>20 20</size></plane></geometry></collision>
        <visual name="v"><geometry><plane><normal>0 0 1</normal><size>20 20</size></plane></geometry></visual>
      </link>
    </model>
    <model name="wall">
      <static>true</static>
      <pose>3 0 0.5 0 0 0</pose>
      <link name="wall">
        <collision name="c"><geometry><box><size>0.2 4 1</size></box></geometry></collision>
        <visual name="v"><geometry><box><size>0.2 4 1</size></box></geometry></visual>
      </link>
    </model>
    <model name="robot">
      <link name="chassis">
        <pose>0 0 0.1 0 0 0</pose>
        <inertial><mass>2</mass><inertia><ixx>0.02</ixx><iyy>0.03</iyy><izz>0.04</izz></inertia></inertial>
        <collision name="c"><geometry><box><size>0.4 0.26 0.1</size></box></geometry></collision>
        <visual name="v"><geometry><box><size>0.4 0.26 0.1</size></box></geometry></visual>
        <collision name="caster">
          <pose>-0.15 0 -0.05 0 0 0</pose>
          <geometry><sphere><radius>0.05</radius></sphere></geometry>
          <surface><friction><ode><mu>0</mu><mu2>0</mu2></ode></friction></surface>
        </collision>
        <sensor name="laser" type="gpu_lidar">
          <!-- 0.25 m above the ground: over the wheels (0.2 m), which would block the side rays -->
          <pose>0 0 0.15 0 0 0</pose>
          <topic>/smoke/scan</topic>
          <update_rate>10</update_rate>
          <always_on>true</always_on>
          <lidar>
            <scan><horizontal><samples>180</samples><resolution>1</resolution>
              <min_angle>-1.5708</min_angle><max_angle>1.5708</max_angle></horizontal></scan>
            <range><min>0.1</min><max>10</max><resolution>0.01</resolution></range>
          </lidar>
        </sensor>
      </link>
      <link name="left_wheel">
        <pose>0 0.17 0.1 -1.5708 0 0</pose>
        <inertial><mass>0.2</mass><inertia><ixx>0.0005</ixx><iyy>0.0005</iyy><izz>0.001</izz></inertia></inertial>
        <collision name="c"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></collision>
        <visual name="v"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></visual>
      </link>
      <link name="right_wheel">
        <pose>0 -0.17 0.1 -1.5708 0 0</pose>
        <inertial><mass>0.2</mass><inertia><ixx>0.0005</ixx><iyy>0.0005</iyy><izz>0.001</izz></inertia></inertial>
        <collision name="c"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></collision>
        <visual name="v"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></visual>
      </link>
      <joint name="left_axle" type="revolute">
        <parent>chassis</parent><child>left_wheel</child><axis><xyz>0 0 1</xyz></axis>
      </joint>
      <joint name="right_axle" type="revolute">
        <parent>chassis</parent><child>right_wheel</child><axis><xyz>0 0 1</xyz></axis>
      </joint>
      <plugin filename="gz-sim-diff-drive-system" name="gz::sim::systems::DiffDrive">
        <left_joint>left_axle</left_joint>
        <right_joint>right_axle</right_joint>
        <wheel_separation>0.34</wheel_separation>
        <wheel_radius>0.1</wheel_radius>
        <topic>/smoke/cmd_vel</topic>
        <odom_topic>/smoke/odom</odom_topic>
      </plugin>
    </model>
  </world>
</sdf>
SDF

echo "== Gazebo Harmonic (server, no window) and ros_gz_bridge"
# without a display (ssh, server), sensors render through EGL
NO_DISPLAY=$([ -z "${DISPLAY:-}" ] && echo --headless-rendering)
setsid ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="-s -r -v 2 $NO_DISPLAY $DIR/smoke.sdf" >"$LOG" 2>&1 &
GZ=$!
setsid ros2 run ros_gz_bridge parameter_bridge \
  /clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock \
  /smoke/scan@sensor_msgs/msg/LaserScan[gz.msgs.LaserScan \
  /smoke/odom@nav_msgs/msg/Odometry[gz.msgs.Odometry \
  /smoke/cmd_vel@geometry_msgs/msg/Twist]gz.msgs.Twist >"$DIR/bridge.log" 2>&1 &
BRIDGE=$!
# setsid: each in its own process group, to also close what they launch (gz sim starts several)
trap 'kill -INT -$BRIDGE -$GZ 2>/dev/null; sleep 2; kill -KILL -$BRIDGE -$GZ 2>/dev/null' EXIT

timeout 120 python3 - <<'PY'
import math
import time

import rclpy
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from rclpy.wait_for_message import wait_for_message
from rosgraph_msgs.msg import Clock
from sensor_msgs.msg import LaserScan

rclpy.init()
node = rclpy.create_node('smoke_test')
failures = 0


def result(good, text):
    global failures
    print('  %s %s' % ('OK   ' if good else 'FAIL ', text))
    failures += 0 if good else 1


def wait_for(msg_type, topic, seconds):
    good, msg = wait_for_message(msg_type, node, topic, time_to_wait=seconds)
    return msg if good else None


# the first Gazebo start takes a while (loading ogre2 and the systems): up to 90 s
scan = wait_for(LaserScan, '/smoke/scan', 90.0)
if scan is None:
    result(False, 'no messages on /smoke/scan after 90 s')
else:
    r = [x for x in scan.ranges if math.isfinite(x)]
    print('  INFO  /smoke/scan: %d samples, minimum %.2f m' % (len(scan.ranges), min(r) if r else float('nan')))
    result(len(scan.ranges) == 180 and r and 2.7 < min(r) < 3.1, 'the laser sees the wall at 2.9 m')

sim_clock = []
node.create_subscription(Clock, '/clock', lambda m: sim_clock.append(m.clock.sec + m.clock.nanosec * 1e-9), 10)
odom0 = wait_for(Odometry, '/smoke/odom', 10.0)
while not sim_clock and rclpy.ok():
    rclpy.spin_once(node, timeout_sec=1.0)
if odom0 is None or not sim_clock:
    result(False, 'no /smoke/odom or /clock')
else:
    # 0.5 m/s for 2 s of simulated time, whatever the real time factor of the machine
    pub = node.create_publisher(Twist, '/smoke/cmd_vel', 10)
    order = Twist()
    order.linear.x = 0.5
    t_sim0, t_real0 = sim_clock[-1], time.time()
    while sim_clock[-1] - t_sim0 < 2.0 and time.time() - t_real0 < 60:
        pub.publish(order)
        rclpy.spin_once(node, timeout_sec=0.05)
    factor = (sim_clock[-1] - t_sim0) / (time.time() - t_real0)
    pub.publish(Twist())
    odom1 = wait_for(Odometry, '/smoke/odom', 10.0)
    x0, x1 = odom0.pose.pose.position.x, odom1.pose.pose.position.x if odom1 else float('nan')
    print('  INFO  real time factor %.2f' % factor)
    result(x1 - x0 > 0.6, 'cmd_vel moves the robot from x=%.2f to x=%.2f (expected ~1 m)' % (x0, x1))
node.destroy_node()
rclpy.shutdown()
raise SystemExit(failures)
PY
RC=$?
[ $RC -eq 124 ] && fail "the Gazebo test did not finish in 120 s" || FAILURES=$((FAILURES + RC))

if grep -qiE 'segmentation fault|core dumped|\[err\]|error while loading' "$LOG"; then fail "Gazebo errors in $LOG"; fi
echo
[ $FAILURES -eq 0 ] && echo "SMOKE TEST OK" || echo "SMOKE TEST: $FAILURES failure(s), logs in $DIR"
exit $FAILURES
