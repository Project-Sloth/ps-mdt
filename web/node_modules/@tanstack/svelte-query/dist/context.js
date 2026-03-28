import { getContext, setContext } from 'svelte';
import { readable } from 'svelte/store';
const _contextKey = '$$_queryClient';
/** Retrieves a Client from Svelte's context */
export const getQueryClientContext = () => {
    const client = getContext(_contextKey);
    if (!client) {
        throw new Error('No QueryClient was found in Svelte context. Did you forget to wrap your component with QueryClientProvider?');
    }
    return client;
};
/** Sets a QueryClient on Svelte's context */
export const setQueryClientContext = (client) => {
    setContext(_contextKey, client);
};
const _isRestoringContextKey = '$$_isRestoring';
/** Retrieves a `isRestoring` from Svelte's context */
export const getIsRestoringContext = () => {
    try {
        const isRestoring = getContext(_isRestoringContextKey);
        return isRestoring ? isRestoring : readable(false);
    }
    catch (error) {
        return readable(false);
    }
};
/** Sets a `isRestoring` on Svelte's context */
export const setIsRestoringContext = (isRestoring) => {
    setContext(_isRestoringContextKey, isRestoring);
};
