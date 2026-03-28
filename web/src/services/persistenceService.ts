interface PersistenceConfig {
	storageKey?: string;
	maxSize?: number;
}

export function createPersistenceService(config: PersistenceConfig = {}) {
	const {
		storageKey = "mdt-persistence",
		maxSize = 5 * 1024 * 1024, // 5MB default
	} = config;

	function get<T>(key: string): T | null {
		try {
			const stored = localStorage.getItem(`${storageKey}:${key}`);

			if (!stored) {
				return null;
			}

			return JSON.parse(stored) as T;
		} catch (error) {
			console.warn(
				`Failed to get persisted data for key "${key}":`,
				error,
			);
			return null;
		}
	}

	function set<T>(key: string, data: T): boolean {
		try {
			const serialized = JSON.stringify(data);

			if (serialized.length > maxSize) {
				console.warn(
					`Data for key "${key}" exceeds max size of ${maxSize} bytes.`,
				);
				return false;
			}

			localStorage.setItem(`${storageKey}:${key}`, serialized);
			return true;
		} catch (error) {
			console.warn(
				`Failed to set persisted data for key "${key}":`,
				error,
			);
			return false;
		}
	}

	function update<T>(key: string, updater: (data: T | null) => T): boolean {
		const current = get<T>(key);
		const updated = updater(current);

		return set(key, updated);
	}

	function remove(key: string): void {
		try {
			localStorage.removeItem(`${storageKey}:${key}`);
		} catch (error) {
			console.warn(
				`Failed to remove persisted data for key "${key}":`,
				error,
			);
		}
	}

	return {
		get,
		set,
		update,
		remove,
	};
}
