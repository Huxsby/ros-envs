#!/bin/bash
# ROS 1 smoke test, for Kinetic, Melodic or Noetic: Python libraries, a SMACH machine, and headless Gazebo with a
# differential robot and a laser facing a wall. Checks that the laser sees the wall and that cmd_vel moves the robot,
# and measures the real time factor. Depends on no project. Called through ros/<distro>/smoke-test.sh.
# Usage: bash smoke-test.sh <kinetic|melodic|noetic>   (~30 s; can run next to another simulation: it uses its own ports)
DISTRO=${1:-}
# Gazebo of each distro, and the Python its ROS packages were built for. The Python code below runs on 2.7 and 3.8.
case $DISTRO in
  kinetic) GAZEBO=7 PYTHON=python2 ;;
  melodic) GAZEBO=9 PYTHON=python2 ;;
  noetic) GAZEBO=11 PYTHON=python3 ;;
  *) echo "usage: smoke-test.sh <kinetic|melodic|noetic>" >&2; exit 2 ;;
esac
source "/opt/ros/$DISTRO/setup.bash"
# Own ROS master and Gazebo ports (fixed and arbitrary), so as not to clash with an open simulation on 11311/11345
export ROS_MASTER_URI=http://localhost:11341 GAZEBO_MASTER_URI=http://localhost:11375 ROS_HOSTNAME=localhost
DIR=$(mktemp -d)
LOG=$DIR/roslaunch.log
FAILURES=0
ok()   { echo "  OK    $*"; }
fail() { echo "  FAIL  $*"; FAILURES=$((FAILURES + 1)); }

echo "== Machine"
bash "$(dirname "$0")/../machine.sh" | sed 's/^/  INFO  /'

echo "== Python libraries"
"$PYTHON" - <<'PY' && ok "rospy, smach, smach_ros, cv2, numpy, pandas, matplotlib" || fail "libraries"
import rospy, smach, smach_ros, cv2, numpy, pandas, matplotlib
PY

echo "== SMACH"
"$PYTHON" - <<'PY' && ok "two-state machine (ONE -> TWO -> done)" || fail "SMACH"
# print as a function, which Python 2 needs to pass it to set_loggers
from __future__ import print_function

import smach

# only warnings and errors: its debug lines would hide the result
smach.set_loggers(lambda msg: None, print, lambda msg: None, print)

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
# 180 samples over 180 degrees. The sensor is type="ray": computed by the CPU, it needs no GPU or display.
cat >"$DIR/smoke.world" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.6">
  <world name="smoke">
    <model name="ground">
      <static>true</static>
      <link name="ground">
        <collision name="c"><geometry><plane><normal>0 0 1</normal><size>20 20</size></plane></geometry></collision>
      </link>
    </model>
    <model name="wall">
      <static>true</static>
      <pose>3 0 0.5 0 0 0</pose>
      <link name="wall">
        <collision name="c"><geometry><box><size>0.2 4 1</size></box></geometry></collision>
      </link>
    </model>
    <model name="robot">
      <link name="chassis">
        <pose>0 0 0.1 0 0 0</pose>
        <inertial><mass>2</mass><inertia><ixx>0.02</ixx><iyy>0.03</iyy><izz>0.04</izz></inertia></inertial>
        <collision name="c"><geometry><box><size>0.4 0.26 0.1</size></box></geometry></collision>
        <collision name="caster">
          <pose>-0.15 0 -0.05 0 0 0</pose>
          <geometry><sphere><radius>0.05</radius></sphere></geometry>
          <surface><friction><ode><mu>0</mu><mu2>0</mu2></ode></friction></surface>
        </collision>
        <sensor name="laser" type="ray">
          <!-- 0.25 m above the ground: over the wheels (0.2 m), which would block the side rays -->
          <pose>0 0 0.15 0 0 0</pose>
          <update_rate>10</update_rate>
          <always_on>true</always_on>
          <ray>
            <scan><horizontal><samples>180</samples><resolution>1</resolution>
              <min_angle>-1.5708</min_angle><max_angle>1.5708</max_angle></horizontal></scan>
            <range><min>0.1</min><max>10</max><resolution>0.01</resolution></range>
          </ray>
          <plugin name="laser" filename="libgazebo_ros_laser.so">
            <robotNamespace>/smoke</robotNamespace>
            <topicName>scan</topicName>
            <frameName>laser</frameName>
          </plugin>
        </sensor>
      </link>
      <link name="left_wheel">
        <pose>0 0.17 0.1 -1.5708 0 0</pose>
        <inertial><mass>0.2</mass><inertia><ixx>0.0005</ixx><iyy>0.0005</iyy><izz>0.001</izz></inertia></inertial>
        <collision name="c"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></collision>
      </link>
      <link name="right_wheel">
        <pose>0 -0.17 0.1 -1.5708 0 0</pose>
        <inertial><mass>0.2</mass><inertia><ixx>0.0005</ixx><iyy>0.0005</iyy><izz>0.001</izz></inertia></inertial>
        <collision name="c"><geometry><cylinder><radius>0.1</radius><length>0.04</length></cylinder></geometry></collision>
      </link>
      <joint name="left_axle" type="revolute">
        <parent>chassis</parent><child>left_wheel</child><axis><xyz>0 0 1</xyz></axis>
      </joint>
      <joint name="right_axle" type="revolute">
        <parent>chassis</parent><child>right_wheel</child><axis><xyz>0 0 1</xyz></axis>
      </joint>
      <plugin name="diff_drive" filename="libgazebo_ros_diff_drive.so">
        <robotNamespace>/smoke</robotNamespace>
        <commandTopic>cmd_vel</commandTopic>
        <odometryTopic>odom</odometryTopic>
        <odometryFrame>odom</odometryFrame>
        <robotBaseFrame>chassis</robotBaseFrame>
        <leftJoint>left_axle</leftJoint>
        <rightJoint>right_axle</rightJoint>
        <wheelSeparation>0.34</wheelSeparation>
        <wheelDiameter>0.2</wheelDiameter>
        <wheelTorque>10</wheelTorque>
        <updateRate>50</updateRate>
      </plugin>
    </model>
  </world>
</sdf>
SDF

echo "== Gazebo $GAZEBO (server, no window)"
# setsid: in its own process group, to also close what it launches (master, gzserver)
setsid roslaunch -p 11341 gazebo_ros empty_world.launch world_name:="$DIR/smoke.world" gui:=false >"$LOG" 2>&1 &
GZ=$!
trap 'kill -INT -$GZ 2>/dev/null; sleep 2; kill -KILL -$GZ 2>/dev/null' EXIT

timeout 120 "$PYTHON" - <<'PY'
import math
import time

import rospy
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from rosgraph_msgs.msg import Clock
from sensor_msgs.msg import LaserScan

failures = 0


def result(good, text):
    global failures
    print('  %s %s' % ('OK   ' if good else 'FAIL ', text))
    failures += 0 if good else 1


# the master may still be starting: init_node waits for it. The first Gazebo start takes a while: up to 90 s
rospy.init_node('smoke_test', anonymous=True, disable_signals=True)
scan = None
try:
    scan = rospy.wait_for_message('/smoke/scan', LaserScan, 90.0)
except rospy.ROSException:
    result(False, 'no messages on /smoke/scan after 90 s')
if scan is not None:
    # not math.isfinite, which Python 2 lacks
    r = [x for x in scan.ranges if not (math.isinf(x) or math.isnan(x))]
    print('  INFO  /smoke/scan: %d samples, minimum %.2f m' % (len(scan.ranges), min(r) if r else float('nan')))
    result(len(scan.ranges) == 180 and bool(r) and 2.7 < min(r) < 3.1, 'the laser sees the wall at 2.9 m')

odom = []
sim_clock = []
rospy.Subscriber('/smoke/odom', Odometry, lambda m: odom.append(m.pose.pose.position.x))
rospy.Subscriber('/clock', Clock, lambda m: sim_clock.append(m.clock.to_sec()))
pub = rospy.Publisher('/smoke/cmd_vel', Twist, queue_size=10)
start = time.time()
while (not odom or not sim_clock) and time.time() - start < 15:
    time.sleep(0.1)
if not odom or not sim_clock:
    result(False, 'no /smoke/odom or /clock')
else:
    # 0.5 m/s for 2 s of simulated time, whatever the real time factor of the machine
    order = Twist()
    order.linear.x = 0.5
    x0, t_sim0, t_real0 = odom[-1], sim_clock[-1], time.time()
    while sim_clock[-1] - t_sim0 < 2.0 and time.time() - t_real0 < 60:
        pub.publish(order)
        time.sleep(0.05)
    factor = (sim_clock[-1] - t_sim0) / (time.time() - t_real0)
    pub.publish(Twist())
    time.sleep(0.2)
    print('  INFO  real time factor %.2f' % factor)
    result(odom[-1] - x0 > 0.6, 'cmd_vel moves the robot from x=%.2f to x=%.2f (expected ~1 m)' % (x0, odom[-1]))
rospy.signal_shutdown('done')
raise SystemExit(failures)
PY
RC=$?
[ $RC -eq 124 ] && fail "the Gazebo test did not finish in 120 s" || FAILURES=$((FAILURES + RC))

if grep -qE 'process has died|Segmentation fault' "$LOG"; then fail "Gazebo errors in $LOG"; fi
echo
[ $FAILURES -eq 0 ] && echo "SMOKE TEST OK" || echo "SMOKE TEST: $FAILURES failure(s), logs in $DIR"
exit $FAILURES
