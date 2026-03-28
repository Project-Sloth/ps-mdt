import { derived, get, readable } from 'svelte/store';
import { noop, notifyManager } from '@tanstack/query-core';
import { useIsRestoring } from './useIsRestoring.js';
import { useQueryClient } from './useQueryClient.js';
import { isSvelteStore } from './utils.js';
export function createBaseQuery(options, Observer, queryClient) {
    /** Load query client */
    const client = useQueryClient(queryClient);
    const isRestoring = useIsRestoring();
    /** Converts options to a svelte store if not already a store object */
    const optionsStore = isSvelteStore(options) ? options : readable(options);
    /** Creates a store that has the default options applied */
    const defaultedOptionsStore = derived([optionsStore, isRestoring], ([$optionsStore, $isRestoring]) => {
        const defaultedOptions = client.defaultQueryOptions($optionsStore);
        defaultedOptions._optimisticResults = $isRestoring
            ? 'isRestoring'
            : 'optimistic';
        return defaultedOptions;
    });
    /** Creates the observer */
    const observer = new Observer(client, get(defaultedOptionsStore));
    defaultedOptionsStore.subscribe(($defaultedOptions) => {
        observer.setOptions($defaultedOptions);
    });
    const result = derived(isRestoring, ($isRestoring, set) => {
        const unsubscribe = $isRestoring
            ? noop
            : observer.subscribe(notifyManager.batchCalls(set));
        observer.updateResult();
        return unsubscribe;
    });
    /** Subscribe to changes in result and defaultedOptionsStore */
    const { subscribe } = derived([result, defaultedOptionsStore], ([$result, $defaultedOptionsStore]) => {
        $result = observer.getOptimisticResult($defaultedOptionsStore);
        return !$defaultedOptionsStore.notifyOnChangeProps
            ? observer.trackResult($result)
            : $result;
    });
    return { subscribe };
}
