<template>
  <div class="gcode-viewer-3d">
    <!-- Quick view controls: top-left overlay -->
    <div class="viewer-quick-views">
      <div class="btn-row">
        <v-tooltip top>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setTopView"
              title="Top View"
            >
              <v-icon small>mdi-chevron-up</v-icon>
            </v-btn>
          </template>
          <span>Top</span>
        </v-tooltip>
        <v-tooltip top>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setBottomView"
              title="Bottom View"
            >
              <v-icon small>mdi-chevron-down</v-icon>
            </v-btn>
          </template>
          <span>Bottom</span>
        </v-tooltip>
      </div>
      <div class="btn-row">
        <v-tooltip right>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setLeftView"
              title="Left View"
            >
              <v-icon small>mdi-chevron-left</v-icon>
            </v-btn>
          </template>
          <span>Left</span>
        </v-tooltip>
        <v-tooltip right>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setRightView"
              title="Right View"
            >
              <v-icon small>mdi-chevron-right</v-icon>
            </v-btn>
          </template>
          <span>Right</span>
        </v-tooltip>
      </div>
      <div class="btn-row">
        <v-tooltip right>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setFrontView"
              title="Front View"
            >
              <v-icon small>mdi-arrow-collapse-left</v-icon>
            </v-btn>
          </template>
          <span>Front</span>
        </v-tooltip>
        <v-tooltip right>
          <template v-slot:activator="{ on }">
            <v-btn
              icon
              small
              class="viewer-btn"
              v-on="on"
              @click.stop.prevent="setBackView"
              title="Back View"
            >
              <v-icon small>mdi-arrow-collapse-right</v-icon>
            </v-btn>
          </template>
          <span>Back</span>
        </v-tooltip>
      </div>
    </div>
    <canvas
      ref="canvas"
      @mousedown="onCanvasMouseDown"
      @click="onCanvasClick"
    ></canvas>
    <div
      v-if="gcode"
      class="gcode-overlay"
      :class="{ collapsed: overlayCollapsed }"
    >
      <div class="overlay-header">
        <button
          class="collapse-toggle"
          @click="toggleOverlay"
          :title="overlayCollapsed ? 'Expand G-code' : 'Collapse G-code'"
        >
          <span v-if="overlayCollapsed">◀</span>
          <span v-else>▶</span>
        </button>
        <span class="overlay-title">
          {{ gcodeLineCount }} lines{{
            highlightedLines.length > 0
              ? ` (${highlightedLines.length} selected)`
              : ""
          }}
        </span>
        <button
          v-if="highlightedLines.length > 0"
          class="header-button"
          @click="clearSelection"
          title="Clear selection"
        >
          <v-icon small>mdi-close</v-icon>
        </button>
        <button
          v-if="highlightedLines.length > 0"
          class="header-button copy-button"
          @click="copySelectedLines"
          :title="copySuccess ? 'Copied!' : 'Copy selected lines to clipboard'"
        >
          <v-icon small>{{
            copySuccess ? "mdi-check" : "mdi-content-copy"
          }}</v-icon>
        </button>
      </div>
      <div
        v-if="!overlayCollapsed"
        class="gcode-lines-container"
        ref="overlayContainer"
      >
        <div
          v-for="(line, index) in allGcodeLines"
          :key="index"
          :class="[
            'gcode-line',
            { 'even-line': index % 2 === 0 },
            { 'odd-line': index % 2 === 1 },
            { 'highlighted-line': highlightedLines.includes(index) },
          ]"
          @click="onOverlayLineClick(index, $event)"
        >
          <span class="line-number">{{ index + 1 }}</span>
          <span class="line-content">{{ line }}</span>
        </div>
      </div>
    </div>
    <div v-if="loading" class="loading-overlay">
      <v-progress-circular indeterminate color="primary"></v-progress-circular>
      <div class="mt-2">Parsing G-code...</div>
    </div>
    <div v-if="error" class="error-overlay">
      <v-alert type="error">{{ error }}</v-alert>
    </div>
  </div>
</template>

<script lang="ts">
// @ts-nocheck - Vue 2 component with complex Three.js integration
import Vue from "vue";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls";

interface StockMetadata {
  type: "cuboid" | "cylinder";
  dimensions: number[];
  originOffset?: { x: number; y: number };
}

export default Vue.extend({
  name: "GCodeViewer3D",

  props: {
    gcode: {
      type: String,
      required: true,
    },
    autoUpdate: {
      type: Boolean,
      default: true,
    },
    highlightedLines: {
      type: Array as () => number[],
      default: () => [],
    },
  },

  data() {
    return {
      loading: false,
      error: null as string | null,
      scene: null as THREE.Scene | null,
      camera: null as THREE.PerspectiveCamera | null,
      renderer: null as THREE.WebGLRenderer | null,
      controls: null as OrbitControls | null,
      animationFrameId: null as number | null,
      lineSegments: new Map<
        number,
        {
          line: THREE.Line;
          originalColor: number;
          originalLineWidth: number;
          from: THREE.Vector3;
          to: THREE.Vector3;
          isArc?: boolean;
          arcCenter?: THREE.Vector3;
          arcClockwise?: boolean;
        }
      >(),
      currentHighlightedLine: null as THREE.Line | null,
      highlightedArrows: [] as THREE.Mesh[],
      raycaster: new THREE.Raycaster(),
      mouse: new THREE.Vector2(),
      lastClickedLine3D: null as number | null,
      overlayCollapsed: true,
      lastClickedLineOverlay: null as number | null,
      isScrolling: false,
      selectionFromOverlay: false,
      copySuccess: false,
    };
  },

  computed: {
    allGcodeLines(): string[] {
      return this.gcode.split("\n");
    },

    gcodeLineCount(): number {
      return this.allGcodeLines.length;
    },
  },

  methods: {
    getGcodeLine(lineNumber: number): string {
      return this.allGcodeLines[lineNumber] || "";
    },

    toggleOverlay() {
      this.overlayCollapsed = !this.overlayCollapsed;
      // If expanding and there are selected lines, scroll to first one
      if (!this.overlayCollapsed && this.highlightedLines.length > 0) {
        setTimeout(() => this.scrollToFirstSelectedLine(), 0);
      }
    },

    onOverlayLineClick(lineNumber: number, event: MouseEvent) {
      event.stopPropagation();
      // Mark that this selection originated from the overlay so we can suppress auto-scroll
      this.selectionFromOverlay = true;

      if (event.shiftKey && this.lastClickedLineOverlay !== null) {
        // Range select
        const start = Math.min(this.lastClickedLineOverlay, lineNumber);
        const end = Math.max(this.lastClickedLineOverlay, lineNumber);
        const newSelection: number[] = [];
        for (let i = start; i <= end; i++) {
          newSelection.push(i);
        }
        this.$emit("lines-selected", newSelection);
      } else if (event.ctrlKey || event.metaKey) {
        // Multi-select
        const currentSelection = [...this.highlightedLines];
        const index = currentSelection.indexOf(lineNumber);
        if (index > -1) {
          currentSelection.splice(index, 1);
        } else {
          currentSelection.push(lineNumber);
        }
        this.$emit("lines-selected", currentSelection);
        this.lastClickedLineOverlay = lineNumber;
      } else {
        // Single select
        this.$emit("lines-selected", [lineNumber]);
        this.lastClickedLineOverlay = lineNumber;
      }
    },

    scrollToFirstSelectedLine() {
      // Prevent re-entry
      if (
        this.highlightedLines.length === 0 ||
        this.overlayCollapsed ||
        this.isScrolling
      ) {
        return;
      }

      this.isScrolling = true;

      try {
        const container = this.$refs.overlayContainer as HTMLElement;
        if (!container) {
          this.isScrolling = false;
          return;
        }

        const firstSelectedLine = Math.min(...this.highlightedLines);
        const lineElements = container.querySelectorAll(".gcode-line");
        if (
          lineElements.length === 0 ||
          firstSelectedLine >= lineElements.length
        ) {
          this.isScrolling = false;
          return;
        }

        const targetLine = lineElements[firstSelectedLine] as HTMLElement;
        if (targetLine) {
          // Scroll container directly instead of using scrollIntoView
          const containerTop = container.scrollTop;
          const targetOffset = targetLine.offsetTop;
          container.scrollTop = targetOffset;
        }
      } catch (error) {
        console.error("Error scrolling to line:", error);
      } finally {
        // Reset flag immediately
        this.isScrolling = false;
      }
    },

    copySelectedLines() {
      if (this.highlightedLines.length === 0) return;

      // Sort the line numbers and get the corresponding lines
      const sortedIndices = [...this.highlightedLines].sort((a, b) => a - b);
      const selectedText = sortedIndices
        .map((index) => this.allGcodeLines[index])
        .join("\n");

      // Copy to clipboard
      navigator.clipboard
        .writeText(selectedText)
        .then(() => {
          // Show success feedback
          this.copySuccess = true;
          setTimeout(() => {
            this.copySuccess = false;
          }, 1500);
        })
        .catch((err) => {
          console.error("Failed to copy to clipboard:", err);
        });
    },

    clearSelection() {
      this.$emit("lines-selected", []);
    },

    initThreeJS() {
      const canvas = this.$refs.canvas as HTMLCanvasElement;
      if (!canvas) return;

      // Scene
      this.scene = new THREE.Scene();
      this.scene.background = new THREE.Color(0x263238); // DWC dark theme

      // Camera
      const aspect = canvas.clientWidth / canvas.clientHeight;
      this.camera = new THREE.PerspectiveCamera(50, aspect, 0.1, 10000);
      this.camera.position.set(100, 100, 100);
      this.camera.lookAt(0, 0, 0);

      // Renderer
      this.renderer = new THREE.WebGLRenderer({
        canvas: canvas,
        antialias: true,
        alpha: false,
      });
      this.renderer.setSize(canvas.clientWidth, canvas.clientHeight);
      this.renderer.setPixelRatio(window.devicePixelRatio);

      // Lighting
      const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
      this.scene.add(ambientLight);

      const directionalLight1 = new THREE.DirectionalLight(0xffffff, 0.4);
      directionalLight1.position.set(1, 1, 1);
      this.scene.add(directionalLight1);

      const directionalLight2 = new THREE.DirectionalLight(0xffffff, 0.2);
      directionalLight2.position.set(-1, -1, -0.5);
      this.scene.add(directionalLight2);

      // Grid
      const gridHelper = new THREE.GridHelper(200, 20, 0x444444, 0x333333);
      this.scene.add(gridHelper);

      // Axes
      const axesHelper = new THREE.AxesHelper(50);
      this.scene.add(axesHelper);

      // Controls
      this.controls = new OrbitControls(this.camera, canvas);
      this.controls.enableDamping = true;
      this.controls.dampingFactor = 0.05;
      this.controls.screenSpacePanning = false; // Use target-based rotation instead of screen-space panning
      this.controls.minDistance = 10;
      this.controls.maxDistance = 1000;

      // Mouse button configuration:
      // LEFT (0) = rotate/orbit camera around target
      // MIDDLE (1) = pan camera (screen-space movement)
      // RIGHT (2) = zoom
      this.controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.PAN,
        RIGHT: THREE.MOUSE.DOLLY,
      };

      // Start animation loop
      this.animate();
    },

    animate() {
      this.animationFrameId = requestAnimationFrame(this.animate);

      if (this.controls) {
        this.controls.update();
      }

      if (this.renderer && this.scene && this.camera) {
        this.renderer.render(this.scene, this.camera);
      }
    },

    onWindowResize() {
      const canvas = this.$refs.canvas as HTMLCanvasElement;
      if (!canvas || !this.camera || !this.renderer) return;

      const width = canvas.clientWidth;
      const height = canvas.clientHeight;

      this.camera.aspect = width / height;
      this.camera.updateProjectionMatrix();

      this.renderer.setSize(width, height);
    },

    onCanvasMouseDown(event: MouseEvent) {
      // Prevent text selection when dragging
      event.preventDefault();
    },

    onCanvasClick(event: MouseEvent) {
      if (!this.camera || !this.scene) return;

      const canvas = this.$refs.canvas as HTMLCanvasElement;
      const rect = canvas.getBoundingClientRect();

      // Calculate mouse position in normalized device coordinates (-1 to +1)
      this.mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      this.mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

      // Update raycaster
      this.raycaster.setFromCamera(this.mouse, this.camera);

      // Find intersected lines
      const lines: THREE.Line[] = [];
      this.lineSegments.forEach((segment) => lines.push(segment.line));

      const intersects = this.raycaster.intersectObjects(lines);

      if (intersects.length > 0) {
        // Find which line was clicked
        const clickedLine = intersects[0].object as THREE.Line;

        // Find the line number for this line
        for (const [lineNumber, segment] of this.lineSegments.entries()) {
          if (segment.line === clickedLine) {
            // Emit event with shift key state for range selection
            this.$emit("line-selected", lineNumber, event.shiftKey);

            // Always update last clicked line for range selections
            this.lastClickedLine3D = lineNumber;
            break;
          }
        }
      }
    },

    createHighlightArrow(fromVec: THREE.Vector3, toVec: THREE.Vector3) {
      if (!this.scene) return;

      const direction = new THREE.Vector3().subVectors(toVec, fromVec);
      const lineLength = direction.length();
      direction.normalize();

      // Arrow size: 8% of line length, minimum 1mm, maximum 3mm
      const arrowLength = Math.max(1, Math.min(lineLength * 0.08, 3));

      // Skip arrows if line is shorter than 1.1x the arrow length
      if (lineLength < arrowLength * 1.1) return;

      // Minimum spacing between arrows: 15mm
      const minSpacing = 15;

      // Calculate how many arrows we can fit
      const numArrows = Math.floor(lineLength / minSpacing);

      if (numArrows === 0) {
        // Line is shorter than 15mm - show single centered arrow
        this.createSingleArrow(fromVec, toVec, direction, arrowLength, 0.5);
      } else {
        // Calculate actual spacing to distribute arrows evenly
        const actualSpacing = lineLength / (numArrows + 1);

        // Create arrows at regular intervals along the line
        for (let i = 1; i <= numArrows; i++) {
          const position = (i * actualSpacing) / lineLength;
          this.createSingleArrow(
            fromVec,
            toVec,
            direction,
            arrowLength,
            position,
          );
        }
      }
    },

    // Helper: set camera to a specific direction vector relative to current controls.target
    setCameraToDirection(dir: THREE.Vector3, up?: THREE.Vector3) {
      if (!this.camera || !this.controls) return;
      const target = this.controls.target.clone();
      const currentDistance = this.camera.position.distanceTo(target);
      const distance = currentDistance > 0 ? currentDistance : 200;
      const newPos = dir
        .clone()
        .normalize()
        .multiplyScalar(distance)
        .add(target);
      this.camera.position.copy(newPos);
      if (up && up.isVector3) {
        this.camera.up.copy(up);
      }
      this.camera.lookAt(target);
      this.controls.update();
    },

    setTopView() {
      // Y is up in Three.js; top view is +Y
      this.setCameraToDirection(
        new THREE.Vector3(0, 1, 0),
        new THREE.Vector3(0, 0, -1),
      );
    },
    setFrontView() {
      // Front should look towards +Z in this scene (since grid is XZ plane and +Y is up)
      this.setCameraToDirection(
        new THREE.Vector3(0, 0, 1),
        new THREE.Vector3(0, 1, 0),
      );
    },
    setBackView() {
      this.setCameraToDirection(
        new THREE.Vector3(0, 0, -1),
        new THREE.Vector3(0, 1, 0),
      );
    },
    setBottomView() {
      this.setCameraToDirection(
        new THREE.Vector3(0, -1, 0),
        new THREE.Vector3(0, 0, 1),
      );
    },
    setLeftView() {
      this.setCameraToDirection(
        new THREE.Vector3(-1, 0, 0),
        new THREE.Vector3(0, 1, 0),
      );
    },
    setRightView() {
      this.setCameraToDirection(
        new THREE.Vector3(1, 0, 0),
        new THREE.Vector3(0, 1, 0),
      );
    },
    setFrontView() {
      this.setCameraToDirection(
        new THREE.Vector3(0, 0, -1),
        new THREE.Vector3(0, 1, 0),
      );
    },
    setBackView() {
      this.setCameraToDirection(
        new THREE.Vector3(0, 0, 1),
        new THREE.Vector3(0, 1, 0),
      );
    },

    createArcHighlightArrow(
      fromVec: THREE.Vector3,
      toVec: THREE.Vector3,
      centerVec: THREE.Vector3,
      clockwise: boolean,
    ) {
      if (!this.scene) return;

      // Convert 3D vectors to 2D for arc calculation (XY plane)
      const from2D = new THREE.Vector2(fromVec.x, -fromVec.z);
      const to2D = new THREE.Vector2(toVec.x, -toVec.z);
      const center2D = new THREE.Vector2(centerVec.x, -centerVec.z);

      // Calculate arc parameters
      const startVec = new THREE.Vector2().subVectors(from2D, center2D);
      const endVec = new THREE.Vector2().subVectors(to2D, center2D);
      const radius = startVec.length();

      let startAngle = Math.atan2(startVec.y, startVec.x);
      let endAngle = Math.atan2(endVec.y, endVec.x);

      // Calculate angular difference (normalized)
      let delta = endAngle - startAngle;
      while (delta > Math.PI) delta -= 2 * Math.PI;
      while (delta < -Math.PI) delta += 2 * Math.PI;

      // Adjust for direction
      if (!clockwise && delta < 0) {
        endAngle += Math.PI * 2;
        delta = endAngle - startAngle;
      } else if (clockwise && delta > 0) {
        endAngle -= Math.PI * 2;
        delta = endAngle - startAngle;
      }

      // Calculate arc length
      const arcLength = Math.abs(delta * radius);

      // Arrow size
      const arrowLength = Math.max(1, Math.min(arcLength * 0.08, 3));
      if (arcLength < arrowLength * 1.1) return;

      // Minimum spacing
      const minSpacing = 15;
      const numArrows = Math.floor(arcLength / minSpacing);

      if (numArrows === 0) {
        // Single arrow at midpoint
        this.createSingleArcArrow(
          from2D,
          to2D,
          center2D,
          startAngle,
          endAngle,
          radius,
          arrowLength,
          0.5,
          fromVec.y,
          clockwise,
        );
      } else {
        const actualSpacing = arcLength / (numArrows + 1);
        for (let i = 1; i <= numArrows; i++) {
          const position = (i * actualSpacing) / arcLength;
          this.createSingleArcArrow(
            from2D,
            to2D,
            center2D,
            startAngle,
            endAngle,
            radius,
            arrowLength,
            position,
            fromVec.y,
            clockwise,
          );
        }
      }
    },

    createSingleArcArrow(
      from2D: THREE.Vector2,
      to2D: THREE.Vector2,
      center2D: THREE.Vector2,
      startAngle: number,
      endAngle: number,
      radius: number,
      arrowLength: number,
      position: number,
      zHeight: number,
      clockwise: boolean,
    ) {
      if (!this.scene) return;

      // Calculate angle at this position along the arc
      const angle = startAngle + (endAngle - startAngle) * position;

      // Calculate position on arc
      const x = center2D.x + radius * Math.cos(angle);
      const y = center2D.y + radius * Math.sin(angle);
      const arrowOrigin = new THREE.Vector3(x, zHeight, -y);

      // Calculate tangent direction (perpendicular to radius)
      // For CCW arc, tangent is +90°; for CW, -90°
      const tangentAngle = angle + (clockwise ? -Math.PI / 2 : Math.PI / 2);
      const direction = new THREE.Vector3(
        Math.cos(tangentAngle),
        0,
        -Math.sin(tangentAngle),
      ).normalize();

      const arrowRadius = arrowLength * 0.2;
      const coneGeometry = new THREE.ConeGeometry(arrowRadius, arrowLength, 8);
      const arrowColor = 0xff1493;
      const coneMaterial = new THREE.MeshPhongMaterial({
        color: arrowColor,
        emissive: arrowColor,
        emissiveIntensity: 0.8,
      });
      const cone = new THREE.Mesh(coneGeometry, coneMaterial);

      cone.position
        .copy(arrowOrigin)
        .add(direction.clone().multiplyScalar(arrowLength / 2));

      const upVector = new THREE.Vector3(0, 1, 0);
      const quaternion = new THREE.Quaternion().setFromUnitVectors(
        upVector,
        direction,
      );
      cone.setRotationFromQuaternion(quaternion);

      this.scene.add(cone);
      this.highlightedArrows.push(cone);
    },

    createSingleArrow(
      fromVec: THREE.Vector3,
      toVec: THREE.Vector3,
      direction: THREE.Vector3,
      arrowLength: number,
      position: number,
    ) {
      if (!this.scene) return;

      // Position arrow at specified position along line
      const arrowOrigin = fromVec.clone().lerp(toVec, position);
      const arrowRadius = arrowLength * 0.2; // Wider base (was 0.15)

      // Create cone geometry for smooth appearance
      const coneGeometry = new THREE.ConeGeometry(arrowRadius, arrowLength, 8);
      // Very bright orange/pink color for highlighted arrow
      const arrowColor = 0xff1493; // Deep pink - very visible
      const coneMaterial = new THREE.MeshPhongMaterial({
        color: arrowColor,
        emissive: arrowColor,
        emissiveIntensity: 0.8, // Very high intensity for maximum visibility
      });
      const cone = new THREE.Mesh(coneGeometry, coneMaterial);

      // Position and orient cone
      cone.position
        .copy(arrowOrigin)
        .add(direction.clone().multiplyScalar(arrowLength / 2));

      // Align cone with direction vector
      const upVector = new THREE.Vector3(0, 1, 0);
      const quaternion = new THREE.Quaternion().setFromUnitVectors(
        upVector,
        direction,
      );
      cone.setRotationFromQuaternion(quaternion);

      this.scene.add(cone);
      this.highlightedArrows.push(cone);
    },

    async renderGCode() {
      if (!this.gcode || !this.scene) return;

      this.loading = true;
      this.error = null;

      try {
        // Clear previous objects (keep helpers)
        const objectsToRemove: any[] = [];
        this.scene.traverse((obj: any) => {
          if (
            obj.type === "Line" ||
            obj.type === "LineSegments" ||
            obj.type === "Mesh"
          ) {
            if (obj.name !== "grid" && obj.name !== "axes") {
              objectsToRemove.push(obj);
            }
          }
        });
        objectsToRemove.forEach((obj) => this.scene!.remove(obj));

        // Clear highlighted arrows
        this.highlightedArrows.forEach((arrow) => this.scene!.remove(arrow));
        this.highlightedArrows = [];

        // Clear line segment mappings
        this.lineSegments.clear();
        this.currentHighlightedLine = null;

        // Parse G-code
        const { stock, toolpaths } = this.parseGCode(this.gcode);

        // Render stock only if both stock dimensions and origin are provided in metadata
        if (stock && stock.originOffset) {
          this.renderStock(stock);
        }

        // Render toolpaths
        this.renderToolpaths(toolpaths);

        // Auto-fit camera
        this.fitCameraToScene();
      } catch (err: any) {
        console.error("Error rendering G-code:", err);
        this.error = `Failed to render G-code: ${err.message}`;
      } finally {
        this.loading = false;
      }
    },

    parseGCode(gcode: string): {
      stock: StockMetadata | null;
      toolpaths: any[];
    } {
      const lines = gcode.split("\n");
      let stock: StockMetadata | null = null;
      const toolpaths: any[] = [];

      let currentX = 0;
      let currentY = 0;
      let currentZ = 0;
      let currentLevel: any[] = [];
      let lastZ = 0;

      for (let lineNumber = 0; lineNumber < lines.length; lineNumber++) {
        const line = lines[lineNumber];
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith(";")) {
          // Check for stock metadata in comments
          if (trimmed.startsWith("; Stock:")) {
            // Parse stock info from comment (backup if M7500 not found)
          }
          continue;
        }

        // Parse M7500 stock metadata
        if (trimmed.startsWith("M7500")) {
          const keyMatch = trimmed.match(/K"([^"]+)"/);
          const valueMatch = trimmed.match(/V\{([^}]+)\}/);

          if (keyMatch && valueMatch) {
            const key = keyMatch[1];
            const values = valueMatch[1]
              .split(",")
              .map((v) => parseFloat(v.trim()));

            if (key === "stock_cuboid" && values.length === 3) {
              stock = { type: "cuboid", dimensions: values };
            } else if (key === "stock_cylinder" && values.length === 2) {
              stock = { type: "cylinder", dimensions: values };
            } else if (key === "stock_origin" && values.length === 2) {
              if (!stock) {
                // If stock hasn't been defined yet, assume rectangular by default with zero dims
                stock = { type: "cuboid", dimensions: [0, 0, 0] };
              }
              stock.originOffset = { x: values[0], y: values[1] };
            }
          }
          continue;
        }

        // Parse movement commands
        const gMatch = trimmed.match(/^(G0|G1|G2|G3)/);
        if (!gMatch) continue;

        const command = gMatch[1];

        // Extract coordinates
        const xMatch = trimmed.match(/X([-\d.]+)/);
        const yMatch = trimmed.match(/Y([-\d.]+)/);
        const zMatch = trimmed.match(/Z([-\d.]+)/);
        const iMatch = trimmed.match(/I([-\d.]+)/);
        const jMatch = trimmed.match(/J([-\d.]+)/);

        const x = xMatch ? parseFloat(xMatch[1]) : currentX;
        const y = yMatch ? parseFloat(yMatch[1]) : currentY;
        const z = zMatch ? parseFloat(zMatch[1]) : currentZ;

        // Check if we're at a new Z level
        if (z !== lastZ) {
          if (currentLevel.length > 0) {
            toolpaths.push(currentLevel);
          }
          currentLevel = [];
          lastZ = z;
        }

        // Create toolpath segment
        const segment: any = {
          type:
            command === "G0"
              ? "rapid"
              : command === "G2" || command === "G3"
                ? "arc"
                : "linear",
          from: { x: currentX, y: currentY, z: currentZ },
          to: { x, y, z },
          lineNumber: lineNumber,
        };

        // Add arc parameters
        if ((command === "G2" || command === "G3") && iMatch && jMatch) {
          segment.arcCenter = {
            x: currentX + parseFloat(iMatch[1]),
            y: currentY + parseFloat(jMatch[1]),
            z: currentZ,
          };
          segment.clockwise = command === "G2";
        }

        currentLevel.push(segment);

        currentX = x;
        currentY = y;
        currentZ = z;
      }

      // Add final level
      if (currentLevel.length > 0) {
        toolpaths.push(currentLevel);
      }

      return { stock, toolpaths };
    },

    renderStock(stock: StockMetadata) {
      if (!this.scene) return;

      const material = new THREE.MeshPhongMaterial({
        color: 0x2e7d32, // Darker green for better contrast
        transparent: true,
        opacity: 0.2,
        side: THREE.DoubleSide,
      });

      let geometry: any;

      if (stock.type === "cuboid") {
        const [x, y, z] = stock.dimensions;
        geometry = new THREE.BoxGeometry(x, z, y); // X width, Z height, Y depth
        const mesh = new THREE.Mesh(geometry, material);
        // Require origin offset; if missing, do not render stock
        if (!stock.originOffset) {
          return;
        }
        // Position stock so it extends DOWN from Z=0 using origin offset (front-left reference)
        const cx = stock.originOffset.x + x / 2;
        const cz = -(stock.originOffset.y + y / 2);
        mesh.position.set(cx, -z / 2, cz);
        this.scene.add(mesh);

        // Wireframe
        const edges = new THREE.EdgesGeometry(geometry);
        const lineMaterial = new THREE.LineBasicMaterial({
          color: 0x1b5e20,
          linewidth: 1,
        }); // Dark green
        const wireframe = new THREE.LineSegments(edges, lineMaterial);
        wireframe.position.copy(mesh.position);
        this.scene.add(wireframe);
      } else if (stock.type === "cylinder") {
        const [diameter, height] = stock.dimensions;
        const radius = diameter / 2;
        geometry = new THREE.CylinderGeometry(radius, radius, height, 32);
        const mesh = new THREE.Mesh(geometry, material);
        // Center cylinder at origin on XZ plane, extending DOWN from Z=0
        mesh.position.set(0, -height / 2, 0);
        this.scene.add(mesh);

        // Wireframe
        const edges = new THREE.EdgesGeometry(geometry);
        const lineMaterial = new THREE.LineBasicMaterial({
          color: 0x1b5e20,
          linewidth: 1,
        }); // Dark green
        const wireframe = new THREE.LineSegments(edges, lineMaterial);
        wireframe.position.copy(mesh.position);
        this.scene.add(wireframe);
      }
    },

    renderToolpaths(toolpaths: any[][]) {
      if (!this.scene || toolpaths.length === 0) return;

      toolpaths.forEach((level, levelIndex) => {
        if (!level || level.length === 0) return;

        // Color gradient from green to blue by depth
        const depthRatio = levelIndex / Math.max(1, toolpaths.length - 1);
        const color = new THREE.Color();
        color.setRGB(
          0.3 - depthRatio * 0.1, // R: 0.3 -> 0.2
          0.7 - depthRatio * 0.1, // G: 0.7 -> 0.6
          0.3 + depthRatio * 0.7, // B: 0.3 -> 1.0
        );

        level.forEach((segment) => {
          if (!segment || !segment.from || !segment.to) return;

          if (segment.type === "rapid") {
            // Rapid moves: dashed red lines for visibility
            this.renderLine(
              segment.from,
              segment.to,
              0xff0000,
              true,
              segment.lineNumber,
              levelIndex,
            );
          } else if (segment.type === "arc") {
            // Arc moves: curved solid lines
            this.renderArc(
              segment.from,
              segment.to,
              segment.arcCenter,
              segment.clockwise,
              color.getHex(),
              segment.lineNumber,
              levelIndex,
            );
          } else {
            // Linear cutting moves: solid colored lines
            this.renderLine(
              segment.from,
              segment.to,
              color.getHex(),
              false,
              segment.lineNumber,
              levelIndex,
            );
          }
        });
      });
    },

    renderLine(
      from: any,
      to: any,
      color: number,
      dashed: boolean,
      lineNumber?: number,
      levelIndex?: number,
    ) {
      if (!this.scene || !from || !to) return;
      if (from.x === undefined || from.y === undefined || from.z === undefined)
        return;
      if (to.x === undefined || to.y === undefined || to.z === undefined)
        return;

      const fromVec = new THREE.Vector3(from.x, from.z, -from.y); // X stays X, Z→Y (up), Y→-Z (depth)
      const toVec = new THREE.Vector3(to.x, to.z, -to.y);

      const points = [fromVec, toVec];

      const geometry = new THREE.BufferGeometry().setFromPoints(points);
      const linewidth = dashed ? 1 : 2;
      const material = dashed
        ? new THREE.LineDashedMaterial({
            color,
            linewidth,
            dashSize: 2,
            gapSize: 1,
          })
        : new THREE.LineBasicMaterial({ color, linewidth });

      const line = new THREE.Line(geometry, material);

      if (dashed) {
        line.computeLineDistances();
      }

      this.scene.add(line);

      // Store line mapping with from/to vectors for arrow creation
      if (lineNumber !== undefined) {
        this.lineSegments.set(lineNumber, {
          line,
          originalColor: color,
          originalLineWidth: linewidth,
          from: fromVec.clone(),
          to: toVec.clone(),
        });
      }
    },

    renderArc(
      from: any,
      to: any,
      center: any,
      clockwise: boolean,
      color: number,
      lineNumber?: number,
      levelIndex?: number,
    ) {
      if (!this.scene || !from || !to || !center) return;
      if (from.x === undefined || from.y === undefined || from.z === undefined)
        return;
      if (to.x === undefined || to.y === undefined || to.z === undefined)
        return;
      if (center.x === undefined || center.y === undefined) return;

      // Calculate arc parameters
      const startVec = new THREE.Vector2(from.x - center.x, from.y - center.y);
      const endVec = new THREE.Vector2(to.x - center.x, to.y - center.y);

      const radius = startVec.length();
      let startAngle = Math.atan2(startVec.y, startVec.x);
      let endAngle = Math.atan2(endVec.y, endVec.x);

      // Calculate the signed angular difference (normalized to [-π, π])
      let delta = endAngle - startAngle;
      while (delta > Math.PI) delta -= 2 * Math.PI;
      while (delta < -Math.PI) delta += 2 * Math.PI;

      // Determine if we should go clockwise or counter-clockwise based on the shortest path
      // delta < 0 means shortest path is clockwise, delta > 0 means counter-clockwise
      let actualClockwise = delta < 0;

      // However, if the G-code explicitly specified a direction, respect it
      // This handles cases where the long arc is intentional
      // For now, we'll use the G-code's direction but ensure the angle sweep is correct
      actualClockwise = clockwise;

      // Adjust angles to ensure the sweep matches the intended direction
      if (!actualClockwise && endAngle < startAngle) {
        endAngle += Math.PI * 2;
      } else if (actualClockwise && endAngle > startAngle) {
        endAngle -= Math.PI * 2;
      }

      // Create arc curve (Three.js uses the same clockwise semantics)
      const curve = new THREE.EllipseCurve(
        center.x,
        center.y, // center
        radius,
        radius, // x radius, y radius
        startAngle,
        endAngle, // start angle, end angle
        actualClockwise, // sweep direction
        0, // rotation
      );

      const points = curve.getPoints(50); // Increased from 20 for smoother arcs
      const points3D = points.map(
        (p: any) => new THREE.Vector3(p.x, from.z, -p.y),
      );

      const geometry = new THREE.BufferGeometry().setFromPoints(points3D);
      const material = new THREE.LineBasicMaterial({ color, linewidth: 2 });
      const line = new THREE.Line(geometry, material);

      this.scene.add(line);

      // Store line mapping for highlighting
      // For arcs, store the arc metadata so highlighting can follow the curve
      if (lineNumber !== undefined) {
        const fromVec = new THREE.Vector3(from.x, from.z, -from.y);
        const toVec = new THREE.Vector3(to.x, to.z, -to.y);
        const centerVec = new THREE.Vector3(center.x, from.z, -center.y);
        this.lineSegments.set(lineNumber, {
          line,
          originalColor: color,
          originalLineWidth: 2,
          from: fromVec.clone(),
          to: toVec.clone(),
          isArc: true,
          arcCenter: centerVec,
          arcClockwise: actualClockwise,
        });
      }
    },

    fitCameraToScene() {
      if (!this.scene || !this.camera || !this.controls) return;

      // Calculate bounding box of all objects
      const box = new THREE.Box3();

      this.scene.traverse((obj: any) => {
        if (
          obj.type === "Line" ||
          obj.type === "LineSegments" ||
          obj.type === "Mesh"
        ) {
          if (obj.name !== "grid" && obj.name !== "axes") {
            box.expandByObject(obj);
          }
        }
      });

      if (box.isEmpty()) return;

      const center = box.getCenter(new THREE.Vector3());
      const size = box.getSize(new THREE.Vector3());

      const maxDim = Math.max(size.x, size.y, size.z);
      const fov = this.camera.fov * (Math.PI / 180);
      let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2));

      cameraZ *= 1.1; // Minimal zoom out for better view (was 1.5)

      this.camera.position.set(
        center.x + cameraZ * 0.7,
        center.y + cameraZ * 0.7,
        center.z + cameraZ * 0.7,
      );

      this.controls.target.copy(center);
      this.controls.update();
    },
  },

  watch: {
    gcode(newGcode: string) {
      if (this.autoUpdate && newGcode) {
        this.renderGCode();
      }
    },

    highlightedLines(newLineNumbers: number[], oldLineNumbers: number[]) {
      // Remove previous arrows
      this.highlightedArrows.forEach((arrow) => this.scene?.remove(arrow));
      this.highlightedArrows = [];

      // Build fast lookup sets
      const newSet = new Set(newLineNumbers);
      const oldSet = new Set(oldLineNumbers);

      // Restore only those that are no longer selected
      oldLineNumbers.forEach((lineNumber) => {
        if (newSet.has(lineNumber)) return;
        const oldSegment = this.lineSegments.get(lineNumber);
        if (!oldSegment) return;
        const mat: any = oldSegment.line.material;
        if (mat && mat.color) mat.color.setHex(oldSegment.originalColor);
        if ("linewidth" in mat) mat.linewidth = oldSegment.originalLineWidth;
        if ("needsUpdate" in mat) mat.needsUpdate = true;
      });

      // Highlight all selected lines (use the current prop to avoid partial updates)
      // Filter to only include lines that have actual rendered segments (movement commands)
      let toHighlight = Array.from(newSet)
        .filter((lineNum) => this.lineSegments.has(lineNum))
        .sort((a, b) => a - b);

      toHighlight.forEach((lineNumber) => {
        const segment = this.lineSegments.get(lineNumber);
        if (!segment) return;
        const mat: any = segment.line.material;
        if (mat && mat.color) mat.color.setHex(0xffff00);
        if ("linewidth" in mat) mat.linewidth = 4;
        if ("needsUpdate" in mat) mat.needsUpdate = true;

        // Create direction arrows
        if (segment.isArc && segment.arcCenter) {
          this.createArcHighlightArrow(
            segment.from,
            segment.to,
            segment.arcCenter,
            !!segment.arcClockwise,
          );
        } else {
          this.createHighlightArrow(segment.from, segment.to);
        }
      });

      // Open overlay when lines are first selected
      if (newLineNumbers.length > 0 && oldLineNumbers.length === 0) {
        this.overlayCollapsed = false;
      }

      // Scroll to first selected line (deferred to avoid blocking)
      if (
        toHighlight.length > 0 &&
        !this.overlayCollapsed &&
        !this.selectionFromOverlay
      ) {
        setTimeout(() => this.scrollToFirstSelectedLine(), 0);
      }
      // Reset overlay-origin flag so next external update (3D view) can scroll
      this.selectionFromOverlay = false;
    },
  },

  mounted() {
    this.raycaster.params.Line!.threshold = 0.5; // Increase click tolerance for lines
    this.initThreeJS();
    if (this.gcode) {
      this.renderGCode();
    }
    window.addEventListener("resize", this.onWindowResize);
  },

  beforeDestroy() {
    window.removeEventListener("resize", this.onWindowResize);
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
    if (this.controls) {
      this.controls.dispose();
    }
    if (this.renderer) {
      this.renderer.dispose();
    }
  },
});
</script>

<style scoped>
.viewer-quick-views {
  position: absolute;
  left: 12px;
  top: 12px;
  display: flex;
  gap: 6px;
  flex-direction: column;
  z-index: 12;
}
.viewer-quick-views .btn-row {
  display: flex;
  gap: 6px;
}
.viewer-btn {
  background: rgba(255, 255, 255, 0.04);
}
.gcode-viewer-3d {
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 500px;
  border-radius: 4px;
  overflow: hidden;
  background: #263238;
  isolation: isolate;
}

canvas {
  display: block;
  width: 100%;
  height: 100%;
  cursor: grab;
}

canvas:active {
  cursor: grabbing;
}

.gcode-overlay {
  position: absolute;
  top: 10px;
  right: 10px;
  background: rgba(0, 0, 0, 0.9);
  border-radius: 4px;
  font-family: "Courier New", monospace;
  font-size: 11px; /* Reduced ~20% for denser view */
  pointer-events: auto;
  z-index: 5;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  display: flex;
  flex-direction: column;
  max-height: 80vh;
  transition: width 0.3s ease;
  width: 500px;
  user-select: none; /* Prevent browser text selection highlight */
}

.gcode-overlay.collapsed {
  width: auto;
}

.gcode-overlay.collapsed .gcode-lines-container {
  display: none;
}

.overlay-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: rgba(0, 0, 0, 0.8);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 4px 4px 0 0;
}

.gcode-overlay.collapsed .overlay-header {
  border-bottom: none;
  border-radius: 4px;
}

.overlay-title {
  color: #90caf9;
  font-weight: bold;
  font-size: 12px; /* Slightly smaller to match reduced base font */
  user-select: none;
  flex: 1; /* Push buttons to the edges */
}

.collapse-toggle,
.header-button {
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: #90caf9;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 3px;
  font-size: 12px;
  line-height: 1;
  transition:
    background 0.2s ease,
    color 0.2s ease;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

.collapse-toggle:hover,
.header-button:hover {
  background: rgba(255, 255, 255, 0.2);
}

.copy-button.header-button {
  color: #4caf50;
}

.gcode-lines-container {
  overflow-y: auto;
  overflow-x: auto;
  flex: 1;
  min-height: 0;
  user-select: none; /* Disable selection in container */
}

.gcode-line {
  display: flex;
  padding: 0 6px; /* Remove vertical padding, keep slight horizontal spacing */
  white-space: pre;
  line-height: 1.2; /* Tighter line height */
  cursor: pointer;
  color: rgba(255, 255, 255, 0.9);
  user-select: none; /* Disable selection per line */
}

.gcode-line.even-line {
  background-color: rgba(255, 255, 255, 0.02);
}

.gcode-line.odd-line {
  background-color: rgba(255, 255, 255, 0.04);
}

.gcode-line:hover {
  background-color: rgba(33, 150, 243, 0.2) !important;
}

.gcode-line.highlighted-line {
  background-color: rgba(255, 235, 59, 0.3) !important;
  font-weight: bold;
}

.line-number {
  display: inline-block;
  min-width: 45px;
  text-align: right;
  margin-right: 12px;
  color: rgba(255, 255, 255, 0.4);
  user-select: none;
  flex-shrink: 0;
}

.line-content {
  flex: 1;
  color: #ffd700;
  user-select: none; /* Disable selection of content */
}

.loading-overlay,
.error-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  background: rgba(38, 50, 56, 0.9);
  color: white;
}

.error-overlay {
  padding: 20px;
}
</style>
