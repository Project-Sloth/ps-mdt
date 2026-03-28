import { readable } from 'svelte/store';
import { notifyManager, replaceEqualDeep } from '@tanstack/query-core';
import { useQueryClient } from './useQueryClient.js';
function getResult(mutationCache, options) {
    return mutationCache
        .findAll(options.filters)
        .map((mutation) => (options.select ? options.select(mutation) : mutation.state));
}
export function useMutationState(options = {}, queryClient) {
    const client = useQueryClient(queryClient);
    const mutationCache = client.getMutationCache();
    let result = getResult(mutationCache, options);
    const { subscribe } = readable(result, (set) => {
        return mutationCache.subscribe(notifyManager.batchCalls(() => {
            const nextResult = replaceEqualDeep(result, getResult(mutationCache, options));
            if (result !== nextResult) {
                result = nextResult;
                set(result);
            }
        }));
    });
    return { subscribe };
}
