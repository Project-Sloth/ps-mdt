type OverlayInfo = {
	className: string;
	role: string | null;
	zIndex: string;
	opacity: string;
	display: string;
	visibility: string;
	left: number;
	top: number;
	width: number;
	height: number;
};

const overlaySelectors = [
	".popup-overlay",
	".profile-modal-backdrop",
	".bolo-modal-backdrop",
	".vehicle-modal-backdrop",
];

function isElementVisible(element: HTMLElement): boolean {
	const style = window.getComputedStyle(element);
	if (style.display === "none" || style.visibility === "hidden") {
		return false;
	}
	const rect = element.getBoundingClientRect();
	return rect.width > 0 && rect.height > 0;
}

function getOverlays(): OverlayInfo[] {
	const overlays = document.querySelectorAll<HTMLElement>(
		overlaySelectors.join(","),
	);
	return Array.from(overlays)
		.filter((element) => isElementVisible(element))
		.map((element) => {
			const rect = element.getBoundingClientRect();
			const style = window.getComputedStyle(element);
			return {
				className: element.className,
				role: element.getAttribute("role"),
				zIndex: style.zIndex,
				opacity: style.opacity,
				display: style.display,
				visibility: style.visibility,
				left: rect.left,
				top: rect.top,
				width: rect.width,
				height: rect.height,
			};
		});
}

function shouldDebug(): boolean {
	return localStorage.getItem("mdt-debug-input") === "1";
}

function shouldThrow(): boolean {
	return localStorage.getItem("mdt-debug-throw") === "1";
}

export function setupInputDebug(): () => void {
	if (!import.meta.env.DEV) {
		return () => {};
	}

	const handler = (event: PointerEvent) => {
		if (!shouldDebug()) return;
		const overlays = getOverlays();
		if (overlays.length === 0) return;
		const topElement = document.elementFromPoint(
			event.clientX,
			event.clientY,
		);
		console.groupCollapsed(
			`[MDT Debug] pointer ${event.clientX},${event.clientY}`,
		);
		console.log("target", event.target);
		console.log("top", topElement);
		console.table(overlays);
		if (event.composedPath) {
			console.log("path", event.composedPath());
		}
		console.groupEnd();
		if (shouldThrow()) {
			throw new Error("MDT input blocked: overlay present");
		}
	};

	const keyHandler = (event: KeyboardEvent) => {
		if (!shouldDebug()) return;
		const overlays = getOverlays();
		if (overlays.length === 0) return;
		console.groupCollapsed(`[MDT Debug] key ${event.key}`);
		console.table(overlays);
		console.groupEnd();
		if (shouldThrow()) {
			throw new Error("MDT input blocked: overlay present");
		}
	};

	document.addEventListener("pointerdown", handler, true);
	document.addEventListener("keydown", keyHandler, true);

	return () => {
		document.removeEventListener("pointerdown", handler, true);
		document.removeEventListener("keydown", keyHandler, true);
	};
}
