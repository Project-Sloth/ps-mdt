import { QueriesObserver, noop, notifyManager } from '@tanstack/query-core';
import { derived, get, readable } from 'svelte/store';
import { useIsRestoring } from './useIsRestoring.js';
import { useQueryClient } from './useQueryClient.js';
import { isSvelteStore } from './utils.js';
export function createQueries({ queries, ...options }, queryClient) {
    const client = useQueryClient(queryClient);
    const isRestoring = useIsRestoring();
    const queriesStore = isSvelteStore(queries) ? queries : readable(queries);
    const defaultedQueriesStore = derived([queriesStore, isRestoring], ([$queries, $isRestoring]) => {
        return $queries.map((opts) => {
            const defaultedOptions = client.defaultQueryOptions(opts);
            // Make sure the results are already in fetching state before subscribing or updating options
            defaultedOptions._optimisticResults = $isRestoring
                ? 'isRestoring'
                : 'optimistic';
            return defaultedOptions;
        });
    });
    const observer = new QueriesObserver(client, get(defaultedQueriesStore), options);
    defaultedQueriesStore.subscribe(($defaultedQueries) => {
        // Do not notify on updates because of changes in the options because
        // these changes should already be reflected in the optimistic result.
        observer.setQueries($defaultedQueries, options);
    });
    const result = derived([isRestoring], ([$isRestoring], set) => {
        const unsubscribe = $isRestoring
            ? noop
            : observer.subscribe(notifyManager.batchCalls(set));
        return () => unsubscribe();
    });
    const { subscribe } = derived([result, defaultedQueriesStore], 
    // @ts-expect-error svelte-check thinks this is unused
    ([$result, $defaultedQueriesStore]) => {
        const [rawResult, combineResult, trackResult] = observer.getOptimisticResult($defaultedQueriesStore, options.combine);
        $result = rawResult;
        return combineResult(trackResult());
    });
    return { subscribe };
}
