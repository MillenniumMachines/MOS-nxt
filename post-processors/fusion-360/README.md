# Fusion360 Post Processor for nxt

## Intro

The Fusion360 post-processor for nxt outputs a relatively basic gcode flavour that is designed to work with the RRF 3.5+ gcode format. It also targets some custom gcodes implemented by nxt, used for workpiece probing, reference surface probing and tool length probing.

## Installation

1. Download the `nxt-<version>-f360.cps` file from the release matching your installed nxt version.
2. Switch to the **"MANUFACTURE"** workbench in Fusion360.
3. Under the **"Milling"** tab, click the **"NC Program"** icon (the one with a G at the top of a document).
4. Click the **"Folder"** icon to the right of Post (**"Select post from the library"**).
5. Hit the **"Import"** button (Document with Arrow on the left, facing right).
6. Select the `nxt-...-f360.cps` file from your filesystem.
7. Select the newly created `nxt-...-f360.cps` file in the Post Library.
8. Configure the post-processor in the **"Post properties"** section of the **"NC Program"** window to your liking. The default settings should work fine unless you have more advanced needs.
9. Create a setup, add some toolpaths and then run the Post to generate nxt flavoured output gcode.

## Notes

Under **"Machine WCS"** in the **"Post Process"** tab of Fusion360's **"Setup"** configuration is a **"WCS offset"** setting which is where the work offset output is configured. Setting this value to `0` (the default) corresponds to `G54`, which is Work Co-ordinate System 1 in RRF / Duet Web Control terms.

This mismatch might be confusing, but it is done for good reason - if no setup changes are made by the operator, we will still generate code in a work co-ordinate system instead of in machine co-ordinates, which will force probing for the origin. We do not allow generating gcode in machine co-ordinates for safety purposes.

## Usage

By default, the post-processor will wrap your operations with a number of commands that are designed to make life easier for novice machinists. In short, these make your programs feel slightly more like they're running on a 3D printer than a CNC mill.

By default, a program will follow roughly these steps:

  1. Pass tool details from Fusion360 to RepRapFirmware to ease tool changes
  2. Home machine in X, Y and Z using G28
  3. Configure movement options
  4. Probe reference surface using touch probe if using more than 1 tool
  5. Run operations
  6. Park the spindle (this also triggers a spindle stop)
  7. End program

For each of your operations, the following steps will be taken:

  1. If the new work offset is not the current work offset:
     1. Park the spindle (including stop)
     2. Prompt the operator to probe the work piece and save its' zero to the new work offset
  2. Switch into the new work offset
  3. If the new tool is not current tool, or probe was required:
     1. Set new tool
     2. Run tool change process (M6)
     3. Tool change process prompts operator to install right tool, and
     4. Runs G37 to probe the new tool's offset.
  4. Enable VSSC if requested
  5. Start spindle at requested RPM
  6. Wait for spindle to reach target RPM
  7. Move to operation starting position in Z
  8. Move to operation starting position in X and Y
  9. Run cutting moves
  10. Disable VSSC if it was enabled

## Probing

When the operator is prompted to probe the work piece, our default behaviour is to run `G6600` which is a "meta macro" that collects information from the operator before running the actual probing macros to find the work piece.

`G6600` allows the operator to select the type of probing operation they want, and then guides the user through filling out the relevant settings for the probing operation they chose.

The default sequential-probing functionality allows you to run operations on a single work piece in multiple planes, by treating each change in work offset as a change in plane.

`G54` (work offset 0 in Fusion360, work co-ordinate system 1 in Duet Web Control) might indicate machining the top of the work piece, while `G55` (work offset 1 in Fusion360, WCS 2 in DWC) might indicate operations that work on the bottom of the work piece.

As the work offsets are probed just prior to being switched into, the work piece can be rotated manually during the guided probing operation.

If, however, you are working on multiple work pieces in a _single_ plane, then it might make sense to probe all of the work offsets before running any operations.

The `WCS Origin Probing Mode` setting allows you to configure this behaviour.

The default option is `On Change` and means that work offsets will be probed just prior to switching into the work offset.

To work on multiple work pieces in a single plane, you can select `At Start`, which will find all work offsets used within the program and prompt the operator to probe each of them before starting any operations.

The final setting is `None (Expert Mode)`, which will assume that all used work offsets are already configured.

In this mode, no work piece probing code will be generated automatically - but you can still use Fusion360's Inspection -> Probing functionality to create probing operations where and when you need them. Please note the Probing functionality requires a paid Fusion360 license.

You can set individual output settings to `No` to disable some of the default functionality (e.g. "Home Before Start" can be turned off, amongst others), or you can disable all the pre-configuration commands by setting "Output job setup commands" to `No`.

If disabling any or all of these settings, please read the output g-code before running it on your machine to confirm that you have configured the machine in the way that the g-code expects prior to running the program.

## MQTT telemetry (optional)

The post can publish the job's progress to an MQTT broker as it runs: the tool to load, the tool in use and the next one, each tool's details, each operation and the cutting height. A display, logger or other MQTT subscriber can then follow the job. [MQTT telemetry from the posts](../MQTT.md) describes the topics, payloads and timing; they are the same as the FreeCAD machine post's. It is off by default, and the board's firmware must support MQTT.

Turn it on in **Post properties**:

| Property | Default | Role |
|----------|---------|------|
| Enable MQTT telemetry | Off | Connects the board's MQTT client at the start of the file and publishes with `M118 P6` |
| MQTT device ID | *(blank)* | The `{device}` segment of the `duet/{device}/...` topics, also the RRF MQTT client ID. Must match your display or collector. |
| MQTT broker host | *(blank)* | Broker for `M586 P4` (no `mqtt://`). A standalone board needs an IPv4 address (RRF doesn't look up hostnames); a hostname only works in SBC mode. |
| MQTT broker port | `1883` | Broker TCP port |
| MQTT job file name | *(blank)* | Overrides `job_file`, below |

When it's on, **device ID and broker host are required** or the post errors.

What is particular to the Fusion post:

- **`job_file`** is the name of the output file. If that name is only a program number, such as `8910.gcode`, `job.gcode` is used instead; set **MQTT job file name** to give the real name.
- **`tool_name`** is the tool description, as `M4000` gets it.
- **`next_tool`** looks ahead through the sections posted in the same run.
- **`event`** is `start` for the first tool published in a post run and `change` after that, also across setups posted into one file.
- **`op_name`** is the operation comment.
- A feed move that warp speed turns into a `G0` publishes no cutting height, and nor does any move at or above the operation's retract height. Fusion for Personal Use outputs rapid moves as feed moves, and those would otherwise show up as cutting heights.

**Post Process All (PPAll):** use the local **`PPAll`** add-in (sibling repo). It posts each op as temp `8910` (Personal Use split), renames the result to the setup name, and rewrites MQTT `job_file` to the final name and `start` to `change` after the first tool. Each op is still posted on its own, so `next_tool`, the op count and the `end` event are only about that op; see [MQTT telemetry from the posts](../MQTT.md#fusion-360-with-post-process-all-ppall). For a manual Fusion post (no add-in), set the NC output name or **MQTT job file name** yourself.

`node post-processors/fusion-360/run-mqtt-helper-tests.mjs` tests the MQTT code in `nxt.cps` itself, without Fusion.
