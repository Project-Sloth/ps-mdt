import type { DefaultError, InfiniteData, QueryKey } from '@tanstack/query-core';
import type { CreateInfiniteQueryOptions } from './types.js';
export declare function infiniteQueryOptions<TQueryFnData, TError = DefaultError, TData = InfiniteData<TQueryFnData>, TQueryKey extends QueryKey = QueryKey, TPageParam = unknown>(options: CreateInfiniteQueryOptions<TQueryFnData, TError, TData, TQueryKey, TPageParam>): CreateInfiniteQueryOptions<TQueryFnData, TError, TData, TQueryKey, TPageParam>;
//# sourceMappingURL=infiniteQueryOptions.d.ts.map