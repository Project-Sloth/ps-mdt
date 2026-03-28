export interface Notification {
	id: string;
	text: string;
	type: "success" | "error" | "info";
	timestamp: number;
}

const MAX_NOTIFICATIONS = 3;
const NOTIFICATION_DURATION = 4000;

let notifications = $state<Notification[]>([]);
let timeouts = new Map<string, ReturnType<typeof setTimeout>>();

function addNotification(text: string, type: "success" | "error" | "info" = "success") {
	const id = `notif-${Date.now()}-${Math.random().toString(36).slice(2, 5)}`;
	const notification: Notification = { id, text, type, timestamp: Date.now() };

	// Remove oldest if at max
	if (notifications.length >= MAX_NOTIFICATIONS) {
		const oldest = notifications[0];
		removeNotification(oldest.id);
	}

	notifications = [...notifications, notification];

	// Auto-remove after duration
	const timeout = setTimeout(() => {
		removeNotification(id);
	}, NOTIFICATION_DURATION);
	timeouts.set(id, timeout);
}

function removeNotification(id: string) {
	const timeout = timeouts.get(id);
	if (timeout) {
		clearTimeout(timeout);
		timeouts.delete(id);
	}
	notifications = notifications.filter((n) => n.id !== id);
}

function clearAll() {
	for (const [id, timeout] of timeouts) {
		clearTimeout(timeout);
	}
	timeouts.clear();
	notifications = [];
}

export function createNotificationService() {
	return {
		get notifications() {
			return notifications;
		},
		notify: addNotification,
		remove: removeNotification,
		clear: clearAll,
		success: (text: string) => addNotification(text, "success"),
		error: (text: string) => addNotification(text, "error"),
		info: (text: string) => addNotification(text, "info"),
	};
}

// Singleton instance for global use
export const globalNotifications = createNotificationService();

export type NotificationService = ReturnType<typeof createNotificationService>;
