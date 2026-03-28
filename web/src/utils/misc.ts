export function isEnvBrowser(): boolean {
	return import.meta.env.DEV;
}
