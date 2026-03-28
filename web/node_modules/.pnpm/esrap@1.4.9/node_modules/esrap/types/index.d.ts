declare module 'esrap' {
	export interface PrintOptions {
		sourceMapSource?: string;
		sourceMapContent?: string;
		sourceMapEncodeMappings?: boolean; // default true
		indent?: string; // default tab
		quotes?: 'single' | 'double'; // default single
	}
	/**
	 * @returns // TODO
	 */
	export function print(node: {
		type: string;
		[key: string]: any;
	}, opts?: PrintOptions): {
		code: string;
		map: any;
	};

	export {};
}

//# sourceMappingURL=index.d.ts.map