import { derived, get, readable } from 'svelte/store';
import { MutationObserver, noop, notifyManager } from '@tanstack/query-core';
import { useQueryClient } from './useQueryClient.js';
import { isSvelteStore } from './utils.js';
export function createMutation(options, queryClient) {
    const client = useQueryClient(queryClient);
    const optionsStore = isSvelteStore(options) ? options : readable(options);
    const observer = new MutationObserver(client, get(optionsStore));
    let mutate;
    optionsStore.subscribe(($options) => {
        mutate = (variables, mutateOptions) => {
            observer.mutate(variables, mutateOptions).catch(noop);
        };
        observer.setOptions($options);
    });
    const result = readable(observer.getCurrentResult(), (set) => {
        return observer.subscribe(notifyManager.batchCalls((val) => set(val)));
    });
    const { subscribe } = derived(result, ($result) => ({
        ...$result,
        mutate,
        mutateAsync: $result.mutate,
    }));
    return { subscribe };
}
