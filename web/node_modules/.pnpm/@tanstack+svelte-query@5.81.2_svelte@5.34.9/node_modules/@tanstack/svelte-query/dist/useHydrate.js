import { hydrate } from '@tanstack/query-core';
import { useQueryClient } from './useQueryClient.js';
export function useHydrate(state, options, queryClient) {
    const client = useQueryClient(queryClient);
    if (state) {
        hydrate(client, state, options);
    }
}
