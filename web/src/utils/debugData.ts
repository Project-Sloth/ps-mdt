import { isEnvBrowser } from "./misc";
import type { NuiEventName } from "../constants/nuiEvents";

interface DebugEvent {
	action: NuiEventName;
	data: any;
}

export function debugData(events: DebugEvent[], timer = 1000): void {
	if (!isEnvBrowser()) return;

	for (const event of events) {
		setTimeout(() => {
			window.dispatchEvent(
				new MessageEvent("message", {
					data: {
						action: event.action,
						data: event.data,
					},
				}),
			);
		}, timer);
	}
}
