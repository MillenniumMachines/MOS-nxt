# MQTT telemetry from the posts

The FreeCAD machine post and the Fusion 360 post can publish a job's progress to an MQTT broker as it runs: the tool to load, the tool in use and the next one, each tool's details, each operation and the cutting height. A display next to the machine, a logger or any other MQTT subscriber can follow the job without reading the G-code.

It is off by default. The G-code publishes through RRF's own MQTT client (`M586.4`, `M586 P4`, `M118 P6`), so the board's firmware must support MQTT. Both posts give the same lines for the same input. The legacy FreeCAD post does not support it.

Turn it on and set the device ID and broker in each post's settings:

- FreeCAD: [MQTT telemetry](freecad/README.md#mqtt-telemetry-optional) in the FreeCAD README.
- Fusion 360: [MQTT telemetry](fusion-360/README.md#mqtt-telemetry-optional) in the Fusion README.

## Broker and connection

- A standalone board needs the broker's IPv4 address: RRF doesn't look up hostnames. A hostname only works in SBC mode, where DSF resolves it.
- In SBC mode, DSF's MQTT must already be set up (in `dsf-config.g`, not `nxt-user-overrides.g`).
- The device ID is the `<device>` segment of every topic below, and also the RRF MQTT client ID.

At the start of each file the G-code connects the client. It disables MQTT first, because the board refuses `M586.4` while MQTT is still on, as it is from the second job on:

```gcode
(MQTT: connect the RRF client to the broker)
M586 P4 S0
G4 S2
M586.4 C"milo"
M586 P4 H"192.168.1.10" R1883 S1
G4 S3
```

## Topics

| Topic | Events | Published |
|---|---|---|
| `duet/<device>/tool` | `load`, `start`, `change` | `load` before each tool change, `start` or `change` once the tool is in |
| `duet/<device>/tooldef/<tool number>` | `tool` | once per tool, right after the connect |
| `duet/<device>/op` | `op`, `end` | as each operation starts, and `end` after the file's last operation |
| `duet/<device>/z` | `z` | at each new cutting height within an operation |

Every payload is flat JSON with an `event` key. Every publish is retained (`M118 ... R1`), see [Retained messages](#retained-messages).

## Tool events

Each tool change publishes twice, once before its `T` word and once after it:

```gcode
(MQTT: publish the tool to load)
M400
M118 P6 S"{""event"":""load"",""tool_number"":48,""tool_name"":""6mm Endmill"",""previous_tool"":3,""job_file"":""Bracket.gcode""}" T"duet/milo/tool" R1
T48
(MQTT: publish tool change)
M118 P6 S"{""event"":""change"",""tool_number"":48,""tool_name"":""6mm Endmill"",""previous_tool"":3,""next_tool"":5,""next_tool_name"":""Spot Drill"",""job_file"":""Bracket.gcode""}" T"duet/milo/tool" R1
```

- **`load`** is the tool to put in. The `M400` before it makes it arrive when the machine stops for the change, so a display can show the tool to load while the machine waits. It has no `next_tool`.
- **`start`** follows the `T` word of the file's first tool, without `previous_tool`. **`change`** follows each later one.
- **`tool_name`** is the tool's name as the post's `M4000` tool definition has it: the FreeCAD tool controller label without `TC: `, or the Fusion tool description. It's cut to 32 characters, without the characters RRF strings can't hold, and left out when the post has no name for the tool.
- **`next_tool`** is the next different tool the file changes to, so a display can show which tool to get ready. It's `null` after the file's last tool change, and left out when the post can't tell. **`next_tool_name`** is that tool's name, worked out like `tool_name`.
- **`job_file`** is the output file's name. See each post's README for how it's worked out and how to override it.

## Tool details

Right after the connect, each tool the file uses publishes its details to a topic of its own:

```gcode
(MQTT: publish the job's tools)
M118 P6 S"{""event"":""tool"",""tool_number"":48,""tool_name"":""6mm Endmill"",""diameter"":6,""flutes"":3,""rpm"":18000}" T"duet/milo/tooldef/48" R1
```

- **`diameter`** is in mm, rounded to 3 decimals at most.
- **`flutes`** is the tool's flute count.
- **`rpm`** is the spindle speed of the tool's first use in the job.
- A value that is unknown or 0 is left out.
- A tool whose details the post can't read still publishes its number and name. That way the broker doesn't keep another job's details for that tool number.

## Operation events

Each operation publishes as it starts, and an `end` event follows the file's last operation:

```gcode
(MQTT: publish operation start)
M118 P6 S"{""event"":""op"",""op_index"":2,""op_count"":5,""op_name"":""Adaptive"",""tool_number"":48,""next_op_name"":""Profile"",""next_op_tool"":3,""job_file"":""Bracket.gcode""}" T"duet/milo/op" R1
```

- **`op_index`** counts from 1 within the output file, out of **`op_count`**.
- **`op_name`** is the operation's name, cut to 40 characters and to the characters RRF strings can hold. Parentheses go, because RRF in CNC mode reads them as a comment.
  - FreeCAD uses the operation's label. For an operation with a dressup, it uses the label of the operation inside it.
  - Fusion uses the operation comment.
- **`next_op_name`** is `null` on the file's last operation. **`next_op_tool`** is the next operation's tool.
- **`{"event":"end","op_count":5,"job_file":"Bracket.gcode"}`** follows the last operation, before the postamble.

## Cutting heights

Within each operation, the height of the cut publishes just before the first feed move at it:

```gcode
M118 P6 S"{""event"":""z"",""z"":-9.5}" T"duet/milo/z" R1
```

A height publishes when a `G1` moves in X or Y at constant Z, or an arc in the XY plane (`G17`) starts and ends at the same Z. Each operation publishes its first height. After that, a height publishes only if it is at least 0.1 mm from every height that operation has published already.

The result:
- Facing, pocketing and profiles publish one event per pass.
- A raster or 3D finishing pass that keeps returning to the same flat levels publishes each level once, not once per row.
- A helix hole publishes the flat circle at the bottom of each level. A second hole in the same operation publishes nothing new for the levels it shares with the first.

These publish nothing:
- moves whose Z changes as they go, such as ramps, helixes and 3D surfacing
- arcs in the XZ or YZ plane
- canned cycles
- rapid moves
- in the Fusion post, feed moves that warp speed turns into `G0`
- in the Fusion post, moves at or above the operation's retract height. Fusion for Personal Use outputs rapid moves as feed moves, so the moves between passes would otherwise count as levels.

## Timing

RRF runs an `M118` when it reads the line, ahead of the moves still queued. So op, `end` and `z` events can arrive a little before the machine gets there:
- an op event, before the previous operation's last moves are done;
- a `z` event, during the pass before.

There's no `M400` before them, so the machine doesn't stop between operations. The `load` event has an `M400` and arrives when the machine stops. `start` and `change` follow the `T` word, so they arrive once the tool change is done.

## Retained messages

Every publish has `R1`. The broker keeps the last message of each topic and sends it to a client as soon as it subscribes. A display started in the middle of a job therefore gets the current tool, operation, height and every tool's details at once. That's why tool details have a topic per tool: one shared topic would keep only the last tool's.

Retained messages outlive the job:
- Between jobs, a subscriber that connects sees the last job's `end` event and last height. The next job replaces them as it runs.
- A `tooldef` topic for a tool number the current job doesn't use still holds an older job's details. Look up only the tools that the current tool and op events name.
- To clear a topic, publish an empty retained message to it, for example `mosquitto_pub -h <broker> -t duet/milo/tooldef/48 -r -n`.

A subscriber that counts events, such as tool changes, should skip:
- retained messages (MQTT sets the retain flag on them when they arrive on subscribing)
- `load` events

## Line length

Each `M118` line is kept to 240 characters, under the 255 that RRF and DSF accept. A line over that is shortened in a fixed order:

- **Tool events:**
  1. `next_tool_name`, then `tool_name`, are shortened and then dropped.
  2. `job_file` is shortened.
  3. `next_tool`, `previous_tool` and `job_file` are dropped.
- **Op events:**
  1. `next_op_name`, `op_name` and `job_file` are shortened.
  2. `next_op_tool`, `job_file`, `next_op_name` and `op_name` are dropped.
- **Tool details:**
  1. `tool_name` is shortened, then dropped.
  2. `rpm`, `flutes` and `diameter` are dropped.

A shortened string keeps at least 8 characters and ends in `~`. Typical names fit. Two 32-character tool names and a 60-character file name already get the next tool's name shortened.

## Fusion 360 with Post Process All (PPAll)

The PPAll add-in posts each operation on its own and joins the files. It rewrites `job_file` to the joined file's name and `start` to `change` after the first tool. Each post run still sees only its one operation, so the job-wide fields are about that operation alone:
- `next_tool` is `null` in every tool event.
- Every op event says op 1 of 1, with no next operation.
- An `end` event follows every operation.

Until PPAll rewrites these too, a display can use the tool, op name and height from a PPAll job, but not the next tool, the op count or the end.
