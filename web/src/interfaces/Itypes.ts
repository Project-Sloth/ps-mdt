export interface NuiMessage<T = any> {
	action: string;
	data: T;
}

export type NuiEventHandler<T = any> = (data: T) => void;

export interface NuiDebugEvent<T = any> {
	data: T;
	delay?: number;
}
