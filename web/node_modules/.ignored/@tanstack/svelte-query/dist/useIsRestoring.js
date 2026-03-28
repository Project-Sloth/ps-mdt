import { getIsRestoringContext } from './context.js';
export function useIsRestoring() {
    return getIsRestoringContext();
}
