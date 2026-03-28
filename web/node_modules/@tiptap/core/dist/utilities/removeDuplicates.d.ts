/**
 * Removes duplicated values within an array.
 * Supports numbers, strings and objects.
 */
export declare function removeDuplicates<T>(array: T[], by?: {
    (value: any, replacer?: (this: any, key: string, value: any) => any, space?: string | number): string;
    (value: any, replacer?: (number | string)[] | null, space?: string | number): string;
}): T[];
//# sourceMappingURL=removeDuplicates.d.ts.map