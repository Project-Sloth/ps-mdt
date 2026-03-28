import { EditorState, Transaction } from '@tiptap/pm/state';
/**
 * Takes a Transaction & Editor State and turns it into a chainable state object
 * @param config The transaction and state to create the chainable state from
 * @returns A chainable Editor state object
 */
export declare function createChainableState(config: {
    transaction: Transaction;
    state: EditorState;
}): EditorState;
//# sourceMappingURL=createChainableState.d.ts.map