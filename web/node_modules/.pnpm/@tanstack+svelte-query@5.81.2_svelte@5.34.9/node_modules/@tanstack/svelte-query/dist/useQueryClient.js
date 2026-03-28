import { getQueryClientContext } from './context.js';
export function useQueryClient(queryClient) {
    if (queryClient)
        return queryClient;
    return getQueryClientContext();
}
