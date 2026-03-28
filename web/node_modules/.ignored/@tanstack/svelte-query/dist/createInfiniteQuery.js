import { InfiniteQueryObserver } from '@tanstack/query-core';
import { createBaseQuery } from './createBaseQuery.js';
export function createInfiniteQuery(options, queryClient) {
    return createBaseQuery(options, InfiniteQueryObserver, queryClient);
}
